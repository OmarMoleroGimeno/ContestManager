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
    // Never attach IP address, cookies or user identifiers to events.
    sendDefaultPii: false,
    // Perf: sample lightly in prod, more in dev
    tracesSampleRate: 0.1,
    // Session replays on errors only.
    // replaysOnErrorSampleRate stays at 1.0 on purpose: the recording produced
    // by replayIntegration() below is fully redacted (no text, no input values,
    // no media, no network payloads), so lowering the rate would cut debugging
    // value without reducing what a single replay can expose. Revisit if the
    // masking configuration is ever relaxed.
    replaysSessionSampleRate: 0,
    replaysOnErrorSampleRate: 1.0,
    integrations: [
      // Privacy-by-default Session Replay. This app renders DNI/NIE/passport
      // numbers, birth dates (minors included), phone numbers, emails and full
      // names of contest participants, so the recording redacts everything and
      // keeps no allow-list: `unmask` and `unblock` are empty on purpose.
      // These options are stated explicitly rather than relying on SDK
      // defaults, so a dependency bump cannot silently widen what is captured.
      Sentry.replayIntegration({
        // Every text node is replaced with asterisks before it leaves the page.
        maskAllText: true,
        // Every input/textarea/select value is replaced with asterisks.
        maskAllInputs: true,
        // Images, video, audio and svg become empty placeholders.
        blockAllMedia: true,
        // Attributes that commonly hold a second copy of the same data.
        // This list overrides the SDK defaults, so they are repeated here.
        maskAttributes: ['title', 'placeholder', 'aria-label', 'alt', 'value'],
        // Beyond masking, drop form interaction events entirely: merged with
        // the SDK defaults (.sentry-ignore, [data-sentry-ignore], file inputs).
        ignore: ['input', 'textarea', 'select'],
        // Never record request/response payloads or headers. An empty
        // allow-list already disables capture; the rest is pinned so a future
        // SDK default cannot turn it back on.
        networkDetailAllowUrls: [],
        networkCaptureBodies: false,
        networkRequestHeaders: [],
        networkResponseHeaders: [],
        // No exceptions to the rules above. Components opt *into* stronger
        // redaction with .sentry-block / [data-sentry-block]; nothing opts out.
        unmask: [],
        unblock: [],
      }),
    ],
    // Don't capture stack traces from noisy extensions
    ignoreErrors: [
      'ResizeObserver loop limit exceeded',
      'ResizeObserver loop completed with undelivered notifications.',
      'Non-Error promise rejection captured',
    ],
  })
}
