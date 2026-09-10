import { describe, it, expect } from 'vitest'
import { z } from 'zod'
import {
  REDACTED,
  REDACTED_LARGE,
  isSensitiveKey,
  redactSensitive,
  redactRequestData,
  redactQueryString,
  redactUrl,
  capBySize,
  summarizeZodIssues,
  summarizeErrorData,
  redactSentryEvent,
} from './redact'
import { EnrollBodySchema } from './schemas'

describe('isSensitiveKey', () => {
  it('matches the project PII fields regardless of case or separators', () => {
    for (const key of ['dni', 'DNI', 'email', 'Email', 'phone', 'first_name', 'firstName', 'FIRST-NAME', 'last_name', 'birthdate', 'birthDate', 'country', 'full_name', 'fullName']) {
      expect(isSensitiveKey(key)).toBe(true)
    }
  })

  it('matches credential families by fragment', () => {
    for (const key of ['token', 'invite_token', 'inscription_token', 'access_token', 'password', 'passwordHash', 'client_secret', 'SUPABASE_API_KEY', 'authorization', 'Authorization']) {
      expect(isSensitiveKey(key)).toBe(true)
    }
  })

  it('leaves diagnostic fields alone', () => {
    for (const key of ['id', 'category_id', 'contest_id', 'status', 'name', 'round_id', 'value', 'statusCode', 'created_at']) {
      expect(isSensitiveKey(key)).toBe(false)
    }
  })
})

describe('redactSensitive', () => {
  it('redacts a flat object but keeps the keys', () => {
    const out = redactSensitive({
      category_id: 'abc',
      first_name: 'Ana',
      last_name: 'García',
      dni: '12345678Z',
      email: 'ana@example.com',
      phone: '+34600112233',
      birthdate: '2011-03-15',
      country: 'ES',
    }) as Record<string, unknown>

    expect(out).toEqual({
      category_id: 'abc',
      first_name: REDACTED,
      last_name: REDACTED,
      dni: REDACTED,
      email: REDACTED,
      phone: REDACTED,
      birthdate: REDACTED,
      country: REDACTED,
    })
  })

  it('recurses into nested objects', () => {
    const out = redactSensitive({
      body: { participant: { profile: { dni: '12345678Z', notes: 'ok' } } },
    }) as { body: { participant: { profile: Record<string, unknown> } } }

    expect(out.body.participant.profile.dni).toBe(REDACTED)
    expect(out.body.participant.profile.notes).toBe('ok')
  })

  it('recurses into arrays of objects', () => {
    const out = redactSensitive({
      participants: [
        { id: '1', email: 'a@example.com' },
        { id: '2', email: 'b@example.com' },
      ],
    }) as { participants: Array<Record<string, unknown>> }

    expect(out.participants.map(p => p.id)).toEqual(['1', '2'])
    expect(out.participants.map(p => p.email)).toEqual([REDACTED, REDACTED])
  })

  it('handles mixed capitalization and separators at any depth', () => {
    const out = redactSensitive({
      Data: { 'FULL-NAME': 'Ana García', 'BirthDate': '2011-03-15', 'roundId': 'r1' },
    }) as { Data: Record<string, unknown> }

    expect(out.Data['FULL-NAME']).toBe(REDACTED)
    expect(out.Data.BirthDate).toBe(REDACTED)
    expect(out.Data.roundId).toBe('r1')
  })

  it('does not mutate the input', () => {
    const input = { dni: '12345678Z' }
    redactSensitive(input)
    expect(input.dni).toBe('12345678Z')
  })

  it('survives circular references', () => {
    const node: Record<string, unknown> = { email: 'a@example.com' }
    node.self = node
    const out = redactSensitive(node) as Record<string, unknown>
    expect(out.email).toBe(REDACTED)
    expect(out.self).toBe('[redacted:circular]')
  })

  it('keeps repeated (non-circular) sibling references intact', () => {
    const shared = { id: 'x' }
    const out = redactSensitive({ a: shared, b: shared }) as Record<string, Record<string, unknown>>
    expect(out.a).toEqual({ id: 'x' })
    expect(out.b).toEqual({ id: 'x' })
  })

  it('passes through primitives', () => {
    expect(redactSensitive('plain')).toBe('plain')
    expect(redactSensitive(42)).toBe(42)
    expect(redactSensitive(null)).toBe(null)
  })
})

describe('capBySize', () => {
  it('keeps the existing size net for oversized payloads', () => {
    expect(capBySize({ notes: 'x'.repeat(5000) })).toBe(REDACTED_LARGE)
    expect(capBySize('x'.repeat(5000))).toBe(REDACTED_LARGE)
  })

  it('leaves small payloads untouched', () => {
    expect(capBySize({ id: 'x' })).toEqual({ id: 'x' })
  })
})

describe('redactRequestData', () => {
  it('redacts a small JSON string body (the case the size rule missed)', () => {
    const body = JSON.stringify({ first_name: 'Ana', dni: '12345678Z', category_id: 'c1' })
    const out = redactRequestData(body) as string
    expect(out).not.toContain('12345678Z')
    expect(out).not.toContain('Ana')
    expect(out).toContain('category_id')
  })

  it('redacts parsed bodies', () => {
    const out = redactRequestData({ email: 'ana@example.com', quantity: 2 }) as Record<string, unknown>
    expect(out).toEqual({ email: REDACTED, quantity: 2 })
  })

  it('falls back to the size cap for opaque bodies', () => {
    expect(redactRequestData('x'.repeat(5000))).toBe(REDACTED_LARGE)
    expect(redactRequestData('short opaque body')).toBe('short opaque body')
  })
})

describe('redactQueryString / redactUrl', () => {
  it('redacts sensitive query parameter values, keeping the names', () => {
    expect(redactQueryString('page=2&email=ana%40example.com&token=abc'))
      .toBe(`page=2&email=${REDACTED}&token=${REDACTED}`)
  })

  it('redacts inscription tokens embedded in the path', () => {
    expect(redactUrl('/api/public/inscriptions/s3cr3t-token/enroll'))
      .toBe(`/api/public/inscriptions/${REDACTED}/enroll`)
  })

  it('keeps ordinary routes readable', () => {
    expect(redactUrl('/api/contests/123/participants?page=2'))
      .toBe('/api/contests/123/participants?page=2')
  })
})

describe('summarizeZodIssues', () => {
  it('keeps path and code from a real Zod failure and drops the value', () => {
    const parsed = EnrollBodySchema.safeParse({
      category_id: 'not-a-uuid',
      first_name: '',
      last_name: 'García',
      birthdate: '15/03/2011',
      dni: '1',
      email: 'nope',
      phone: '600112233',
    })
    expect(parsed.success).toBe(false)
    const issues = summarizeZodIssues(parsed.error?.issues)
    expect(issues).not.toBeNull()

    const serialized = JSON.stringify(issues)
    expect(serialized).not.toContain('not-a-uuid')
    expect(serialized).not.toContain('García')
    expect(serialized).not.toContain('600112233')
    expect(serialized).not.toContain('nope')

    const paths = issues?.map(i => i.path) ?? []
    expect(paths).toContain('dni')
    expect(paths).toContain('email')
    for (const issue of issues ?? []) {
      expect(typeof issue.code).toBe('string')
      expect(Object.keys(issue).sort()).toEqual(['code', 'message', 'path'])
    }
  })

  it('drops the `input` a Zod issue may carry', () => {
    const parsed = z.object({ dni: z.string() }).safeParse({ dni: 12345678 })
    const issues = summarizeZodIssues(parsed.error?.issues) ?? []
    expect(JSON.stringify(issues)).not.toContain('12345678')
    expect(issues[0]?.path).toBe('dni')
  })

  it('returns null for payloads that are not issue arrays', () => {
    expect(summarizeZodIssues({ dni: 'x' })).toBeNull()
    expect(summarizeZodIssues([{ dni: 'x' }])).toBeNull()
    expect(summarizeZodIssues([])).toBeNull()
  })
})

describe('summarizeErrorData', () => {
  it('wraps Zod issues under `issues`', () => {
    const parsed = EnrollBodySchema.safeParse({ category_id: 'x' })
    const out = summarizeErrorData(parsed.error?.issues) as { issues: unknown[] }
    expect(Array.isArray(out.issues)).toBe(true)
  })

  it('redacts non-Zod error payloads by field name', () => {
    expect(summarizeErrorData({ email: 'ana@example.com', code: 'PGRST116' }))
      .toEqual({ email: REDACTED, code: 'PGRST116' })
  })

  it('returns undefined when there is nothing to report', () => {
    expect(summarizeErrorData(undefined)).toBeUndefined()
    expect(summarizeErrorData(null)).toBeUndefined()
  })
})

describe('redactSentryEvent', () => {
  it('scrubs request data, extra, contexts, breadcrumbs and user', () => {
    const event = {
      request: {
        url: '/api/public/inscriptions/tok3n/enroll?email=ana%40example.com',
        data: { first_name: 'Ana', dni: '12345678Z', category_id: 'c1' },
        headers: { authorization: 'Bearer abc', 'content-type': 'application/json' },
        cookies: { 'sb-access-token': 'abc' },
        query_string: 'email=ana%40example.com&page=1',
      },
      extra: { url: '/x', data: { issues: [{ path: 'dni', code: 'too_small' }] }, phone: '+34600112233' },
      contexts: { payload: { email: 'ana@example.com' } },
      breadcrumbs: [{ category: 'http', data: { dni: '12345678Z', status: 400 } }],
      user: { id: 'u1', email: 'ana@example.com' },
    }

    redactSentryEvent(event)
    const serialized = JSON.stringify(event)

    expect(serialized).not.toContain('12345678Z')
    expect(serialized).not.toContain('ana@example.com')
    expect(serialized).not.toContain('ana%40example.com')
    expect(serialized).not.toContain('+34600112233')
    expect(serialized).not.toContain('Bearer abc')
    expect(serialized).not.toContain('tok3n')

    // Diagnostic signal survives.
    expect((event.request.data as Record<string, unknown>).category_id).toBe('c1')
    expect((event.user as Record<string, unknown>).id).toBe('u1')
    expect(serialized).toContain('too_small')
    expect(serialized).toContain('content-type')
  })

  it('tolerates an event with no payload slots', () => {
    const event: Record<string, unknown> = { message: 'boom' }
    expect(redactSentryEvent(event)).toBe(event)
  })
})
