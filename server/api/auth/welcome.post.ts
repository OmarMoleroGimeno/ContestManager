import { defineEventHandler, readBody, createError } from 'h3'
import { sendWelcomeEmail } from '../../utils/email'
import { z } from 'zod'

const welcomeEmailSchema = z.object({
  email: z.string().email(),
  first_name: z.string().nullable().optional(),
  marketing_consent: z.boolean().optional().default(false),
})

export default defineEventHandler(async (event) => {
  try {
    const body = await readBody(event)
    const validated = welcomeEmailSchema.parse(body)

    sendWelcomeEmail({
      to: validated.email,
      first_name: validated.first_name,
      email: validated.email,
      marketing_consent: validated.marketing_consent,
    }).then((result) => {
      if (result.sent) {
        console.log('[welcome-email] Sent successfully:', result.id)
      } else if (result.error) {
        console.error('[welcome-email] Failed:', result.error)
      }
    }).catch((err) => {
      console.error('[welcome-email] Unhandled error:', err)
    })

    return {
      success: true,
      message: 'Welcome email queued',
    }
  } catch (error: any) {
    if (error instanceof z.ZodError) {
      throw createError({
        statusCode: 400,
        message: 'Invalid payload',
        data: error.errors,
      })
    }
    throw error
  }
})
