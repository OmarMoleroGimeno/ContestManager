// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  ssr: false,
  devtools: { enabled: true },
  modules: [
    '@pinia/nuxt',
    '@nuxtjs/tailwindcss',
    'shadcn-nuxt',
    '@nuxtjs/color-mode',
    ...(process.env.SENTRY_DSN ? ['@sentry/nuxt/module'] : []) as any,
  ],
  sentry: {
    sourceMapsUploadOptions: {
      org: process.env.SENTRY_ORG || '',
      project: process.env.SENTRY_PROJECT || '',
      authToken: process.env.SENTRY_AUTH_TOKEN || '',
    },
  },
  css: ['vue-sonner/style.css'],
  colorMode: {
    classSuffix: ''
  },
  shadcn: {
    prefix: '',
    componentDir: './app/components/ui'
  },
  runtimeConfig: {
    stripeSecretKey: process.env.STRIPE_SECRET_KEY || '',
    stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET || '',
    platformFeeBps: process.env.PLATFORM_FEE_BPS || '500', // 500 bps = 5%
    appBaseUrl: process.env.APP_BASE_URL || 'http://localhost:3000',
    public: {
      supabaseUrl: process.env.SUPABASE_URL || '',
      supabaseAnonKey: process.env.SUPABASE_ANON_KEY || '',
      sentryDsn: process.env.SENTRY_DSN || '',
      sentryEnv: process.env.SENTRY_ENVIRONMENT || process.env.NODE_ENV || 'development',
      appVersion: process.env.APP_VERSION || '',
    }
  },
  nitro: {
    routeRules: {
      '/api/stripe/webhook': { cors: false }
    }
  }
})
