// Nitro global error handler. Logs structured context for every unhandled
// API error. Also captures to Sentry when @sentry/nuxt is active.
//
// PII rule: `err.data` on a 400 holds the Zod `issues`, which can carry the
// rejected input (a mistyped DNI, an email). Neither the hosting provider's
// logs nor Sentry `extra` ever see that value — only the field path and the
// Zod error code. See `server/utils/redact.ts`.
import type { NitroApp } from 'nitropack'
import { redactUrl, summarizeErrorData } from '../utils/redact'

interface NitroErrorLike {
  statusCode?: number
  statusMessage?: string
  message?: string
  data?: unknown
}

export default (nitroApp: NitroApp) => {
  nitroApp.hooks.hook('error', async (error, { event }) => {
    const err = error as Error & NitroErrorLike
    const rawUrl = event?.path || event?.node?.req?.url || ''
    const url = redactUrl(rawUrl)
    const method = event?.node?.req?.method || ''
    const status = err?.statusCode || 500
    // Skip noisy 401/404 for API
    if (status === 401 || status === 404) return

    // Field paths + Zod codes only — never the received values.
    const safeData = summarizeErrorData(err?.data)

    const line = `[nitro-error] ${method} ${url} → ${status} :: ${err?.statusMessage || err?.message || 'unknown'}`
    // eslint-disable-next-line no-console
    console.error(line, safeData ? JSON.stringify(safeData) : '')

    // Sentry capture (lazy import — avoids load when module absent)
    if (process.env.SENTRY_DSN) {
      try {
        const Sentry = await import('@sentry/nuxt')
        Sentry.captureException(err, {
          tags: { status: String(status), method },
          extra: { url, data: safeData },
        })
      } catch { console.error('[error-handler] sentry capture failed') }
    }
  })
}
