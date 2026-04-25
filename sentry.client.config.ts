// Sentry client init (loaded by @sentry/nuxt when SENTRY_DSN set).
// Docs: https://docs.sentry.io/platforms/javascript/guides/nuxt/
import * as Sentry from '@sentry/nuxt'

const dsn = (import.meta as any).env?.VITE_SENTRY_DSN
  || (typeof process !== 'undefined' ? process.env.SENTRY_DSN : '')
  || ''

if (dsn) {
  Sentry.init({
    dsn,
    environment: (typeof process !== 'undefined' && process.env.SENTRY_ENVIRONMENT) || 'production',
    release: (typeof process !== 'undefined' && process.env.APP_VERSION) || undefined,
    // Perf: sample lightly in prod, more in dev
    tracesSampleRate: 0.1,
    // Session replays on errors only
    replaysSessionSampleRate: 0,
    replaysOnErrorSampleRate: 1.0,
    // Don't capture stack traces from noisy extensions
    ignoreErrors: [
      'ResizeObserver loop limit exceeded',
      'ResizeObserver loop completed with undelivered notifications.',
      'Non-Error promise rejection captured',
    ],
  })
}
