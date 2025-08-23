import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

serve(async (req) => {
  const { companyCode, purchaserEmail, purchaseType, totalLicenses, remainingUses } = await req.json()

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: 'TPEAINDEX Assessment <noreply@tpeaindex.com>',
      to: [purchaserEmail],
      subject: 'Your TPEAINDEX Company Code - Leadership Assessment Access',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #1e3a8a;">Your Leadership Assessment Package is Ready!</h2>
          
          <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="color: #1e3a8a; margin-top: 0;">Company Code: <strong style="color: #059669; font-size: 24px;">${companyCode}</strong></h3>
            <p><strong>Package:</strong> ${purchaseType} Pack</p>
            <p><strong>Total Licenses:</strong> ${totalLicenses} assessments</p>
            <p><strong>Remaining Uses:</strong> ${remainingUses}</p>
          </div>

          <h3>How to Share with Your Team:</h3>
          <ol>
            <li>Send your team members this link: <a href="https://tpeaindex.vercel.app">https://tpeaindex.vercel.app</a></li>
            <li>They should click "Enter it here" in the payment section</li>
            <li>Have them enter your company code: <strong>${companyCode}</strong></li>
            <li>They can then take the assessment for free using your license</li>
          </ol>

          <div style="background-color: #fef3c7; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <h4 style="color: #92400e; margin-top: 0;">Important Notes:</h4>
            <ul style="color: #92400e;">
              <li>Each code use will deduct from your remaining licenses</li>
              <li>Code expires in 1 year from purchase date</li>
              <li>Save this email for your records</li>
            </ul>
          </div>

          <p>Questions? Contact us at support@tpeaindex.com</p>
          
          <hr style="margin: 30px 0; border: none; border-top: 1px solid #e5e7eb;">
          <p style="color: #6b7280; font-size: 12px;">
            TPEAINDEX Leadership Assessment<br>
            This email was sent because you purchased a leadership assessment package.
          </p>
        </div>
      `,
    }),
  })

  const data = await res.json()
  
  return new Response(
    JSON.stringify(data),
    { headers: { "Content-Type": "application/json" } },
  )
})