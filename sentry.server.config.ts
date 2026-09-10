// Sentry Nitro init (loaded by @sentry/nuxt when SENTRY_DSN set).
import * as Sentry from '@sentry/nuxt'
import { redactSensitive, redactSentryEvent, type RedactableEvent } from './server/utils/redact'

const dsn = process.env.SENTRY_DSN || ''

if (dsn) {
  Sentry.init({
    dsn,
    environment: process.env.SENTRY_ENVIRONMENT || process.env.NODE_ENV || 'production',
    release: process.env.APP_VERSION || undefined,
    tracesSampleRate: 0.1,
    // Never attach Sentry's default PII (IP address, cookies, user identifiers).
    sendDefaultPii: false,
    // Drop PII by field name before the event leaves the process: request body
    // (+ url, headers, cookies, query string), extra, contexts, breadcrumbs and
    // user. The size cap for opaque bodies (raw webhook payloads) still applies
    // inside the redaction helpers — the two rules complement each other.
    beforeSend(event) {
      try {
        redactSentryEvent(event as RedactableEvent)
      } catch {
        // Fail closed: an event we could not scrub must not be sent.
        return null
      }
      return event
    },
    // Breadcrumbs are also recorded outside `beforeSend` (HTTP, console, DB).
    beforeBreadcrumb(breadcrumb) {
      try {
        if (breadcrumb.data) {
          breadcrumb.data = redactSensitive(breadcrumb.data) as Record<string, unknown>
        }
      } catch {
        return null
      }
      return breadcrumb
    },
  })
}
