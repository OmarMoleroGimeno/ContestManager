import { Resend } from 'resend'

let _resend: Resend | null = null
function getResend(): Resend | null {
  if (_resend) return _resend
  const key = process.env.RESEND_API_KEY || ''
  if (!key) return null
  _resend = new Resend(key)
  return _resend
}

export interface EnrollmentEmailPayload {
  to: string
  first_name: string | null
  contest_name: string
  category_name: string
  amount_paid_cents?: number | null
  is_paid: boolean
  contest_slug?: string | null
}

export async function sendEnrollmentEmail(p: EnrollmentEmailPayload) {
  const resend = getResend()
  if (!resend) {
    console.warn('[email] RESEND_API_KEY not set — skipping')
    return { skipped: true }
  }
  const from = process.env.RESEND_FROM || 'ContestSaas <noreply@contestsaas.app>'
  const amount = p.amount_paid_cents ? `€${(p.amount_paid_cents / 100).toFixed(2)}` : null
  const subject = p.is_paid
    ? `Inscripción confirmada · ${p.contest_name}`
    : `Inscripción recibida · ${p.contest_name}`

  const html = `
<!doctype html>
<html><body style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;color:#111;max-width:560px;margin:0 auto;padding:24px;">
  <div style="border:2px solid #e4e4e7;border-radius:12px;padding:32px;">
    <h1 style="font-size:20px;font-weight:800;text-transform:uppercase;letter-spacing:0.05em;margin:0 0 8px;">
      ${p.is_paid ? '✓ Inscripción confirmada' : '✓ Inscripción recibida'}
    </h1>
    <p style="color:#71717a;font-size:14px;margin:0 0 24px;">
      Hola${p.first_name ? ' ' + p.first_name : ''},
    </p>
    <p style="font-size:14px;line-height:1.6;margin:0 0 24px;">
      Has quedado inscrito en <strong>${p.contest_name}</strong> (${p.category_name}).
      ${p.is_paid && amount ? `El pago de <strong>${amount}</strong> se ha procesado correctamente.` : ''}
    </p>
    <div style="background:#fafafa;border:1px solid #e4e4e7;border-radius:8px;padding:16px;margin:16px 0;">
      <p style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.1em;color:#71717a;margin:0 0 4px;">Concurso</p>
      <p style="font-size:14px;font-weight:600;margin:0 0 12px;">${p.contest_name}</p>
      <p style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.1em;color:#71717a;margin:0 0 4px;">Categoría</p>
      <p style="font-size:14px;font-weight:600;margin:0;">${p.category_name}</p>
    </div>
    <p style="color:#71717a;font-size:12px;margin:24px 0 0;">
      Recibirás más información cuando el concurso comience. Si tienes preguntas, responde a este correo.
    </p>
  </div>
</body></html>`.trim()

  try {
    const r = await resend.emails.send({ from, to: p.to, subject, html })
    return { sent: true, id: (r as any)?.data?.id ?? null }
  } catch (err: any) {
    console.error('[email] resend failed:', err?.message)
    return { error: err?.message }
  }
}
