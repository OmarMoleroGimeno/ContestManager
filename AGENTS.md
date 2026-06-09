## Overview
- Nuxt 4 app (`ssr: false`) → fully client-side SPA. Do not assume server-rendered behavior.
- UI stack: Tailwind + `shadcn-nuxt` (components live in `app/components/ui`).
- State: Pinia via `@pinia/nuxt`.
- Backend integrations: Supabase (client), Stripe (server routes), optional Sentry.

## Commands
- Install: `npm install`
- Dev: `npm run dev` (runs on http://localhost:3000)
- Build: `npm run build`
- Preview prod build: `npm run preview`

No lint, test, or typecheck scripts are defined → do not assume they exist.

## Architecture Notes
- SPA mode (`ssr: false`) means:
  - All pages render client-side
  - Avoid relying on server-only lifecycle unless inside `/server` routes
- Runtime config (`nuxt.config.ts`) is the source of truth for env usage.
  - Private keys: `stripeSecretKey`, `stripeWebhookSecret`
  - Public keys: Supabase + Sentry live under `runtimeConfig.public`

## Server / API
- Nitro server routes exist (e.g. `/api/stripe/webhook`)
- Stripe webhook explicitly disables CORS → do not modify casually

## UI Conventions
- `shadcn-nuxt` is configured with:
  - no prefix
  - components in `app/components/ui`
- Prefer existing UI primitives before adding new ones

## Gotchas
- Sentry module is conditionally enabled via `SENTRY_DSN`
  - Do not assume Sentry is always active
- `postinstall` runs `nuxt prepare` → required for module setup
- Some dependencies are React-based (`@radix-ui/react-*`) but this is a Vue app → do not use them directly

## When Adding Features
- Check if logic belongs in:
  - client (pages/components)
  - server (`/server/api`)
- For anything involving secrets (Stripe, webhooks), always use server routes
- Reuse Tailwind + shadcn patterns instead of introducing new styling systems
