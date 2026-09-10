import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import {
  claimStripeEvent,
  releaseStripeEvent,
  wasStripeEventProcessed,
} from './stripe-idempotency'
import type { SupabaseAdmin } from '~~/server/services/stripe-webhook'

// supabase-js resolves with { data, error } instead of rejecting. These mocks
// reproduce that shape on purpose: a mock that throws would hide the very bug
// these tests exist to catch.
function createMockAdmin(results: {
  insert?: { error: any }
  select?: { data: any; error: any }
  delete?: { error: any }
} = {}) {
  const insert = vi.fn(() => Promise.resolve(results.insert ?? { error: null }))
  const maybeSingle = vi.fn(() =>
    Promise.resolve(results.select ?? { data: null, error: null }),
  )
  const deleteEq = vi.fn(() => Promise.resolve(results.delete ?? { error: null }))
  const from = vi.fn(() => ({
    insert,
    select: vi.fn(() => ({ eq: vi.fn(() => ({ maybeSingle })) })),
    delete: vi.fn(() => ({ eq: deleteEq })),
  }))

  return {
    admin: { from } as unknown as SupabaseAdmin,
    from,
    insert,
    maybeSingle,
    deleteEq,
  }
}

const UNIQUE_VIOLATION = { code: '23505', message: 'duplicate key value' }
const UNDEFINED_TABLE = {
  code: '42P01',
  message: 'relation "public.processed_stripe_events" does not exist',
}

describe('claimStripeEvent', () => {
  it('acquires the claim when the insert succeeds', async () => {
    const { admin, from, insert } = createMockAdmin()

    await expect(claimStripeEvent(admin, 'evt_1', 'checkout.session.completed'))
      .resolves.toBe('acquired')

    expect(from).toHaveBeenCalledWith('processed_stripe_events')
    expect(insert).toHaveBeenCalledWith({
      stripe_event_id: 'evt_1',
      event_type: 'checkout.session.completed',
    })
  })

  it('reports already_processed on unique violation', async () => {
    const { admin } = createMockAdmin({ insert: { error: UNIQUE_VIOLATION } })

    await expect(claimStripeEvent(admin, 'evt_1', 'checkout.session.completed'))
      .resolves.toBe('already_processed')
  })

  // The production failure: migration 0045 never applied, so the table was
  // missing and the old try/catch let the handler run anyway.
  it('throws when the ledger table does not exist', async () => {
    const { admin } = createMockAdmin({ insert: { error: UNDEFINED_TABLE } })

    await expect(claimStripeEvent(admin, 'evt_1', 'checkout.session.completed'))
      .rejects.toThrow(/idempotency_lock_failed/)
  })

  it('throws on any other database error', async () => {
    const { admin } = createMockAdmin({
      insert: { error: { code: '08006', message: 'connection failure' } },
    })

    await expect(claimStripeEvent(admin, 'evt_1', 'checkout.session.completed'))
      .rejects.toThrow(/connection failure/)
  })
})

describe('wasStripeEventProcessed', () => {
  it('returns false when the event is unknown', async () => {
    const { admin } = createMockAdmin({ select: { data: null, error: null } })

    await expect(wasStripeEventProcessed(admin, 'evt_1')).resolves.toBe(false)
  })

  it('returns true when the event is already recorded', async () => {
    const { admin } = createMockAdmin({
      select: { data: { stripe_event_id: 'evt_1' }, error: null },
    })

    await expect(wasStripeEventProcessed(admin, 'evt_1')).resolves.toBe(true)
  })

  it('throws instead of reporting false when the lookup fails', async () => {
    const { admin } = createMockAdmin({ select: { data: null, error: UNDEFINED_TABLE } })

    await expect(wasStripeEventProcessed(admin, 'evt_1'))
      .rejects.toThrow(/idempotency_lookup_failed/)
  })
})

describe('releaseStripeEvent', () => {
  beforeEach(() => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
  })
  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('deletes the claim', async () => {
    const { admin, from, deleteEq } = createMockAdmin()

    await releaseStripeEvent(admin, 'evt_1')

    expect(from).toHaveBeenCalledWith('processed_stripe_events')
    expect(deleteEq).toHaveBeenCalledWith('stripe_event_id', 'evt_1')
  })

  it('logs and swallows a failed rollback', async () => {
    const { admin } = createMockAdmin({ delete: { error: UNDEFINED_TABLE } })

    await expect(releaseStripeEvent(admin, 'evt_1')).resolves.toBeUndefined()
    expect(console.error).toHaveBeenCalledWith(
      '[stripe webhook] idempotency rollback failed:',
      UNDEFINED_TABLE.message,
    )
  })
})
