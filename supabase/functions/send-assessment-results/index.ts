import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

serve(async (req) => {
  const { 
    email, 
    name, 
    archetype, 
    supportScore, 
    responsibleScore, 
    selflessScore, 
    accountabilityScore,
    recommendations 
  } = await req.json()

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: 'TPEAINDEX Assessment <noreply@tpeaindex.com>',
      to: [email],
      subject: `Your Leadership Assessment Results - ${archetype}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #1e3a8a 0%, #2563eb 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0;">
            <h1 style="margin: 0; font-size: 28px;">Leadership Assessment Results</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">TPEAINDEX Positive Effect Leadership</p>
          </div>

          <div style="padding: 30px; background-color: #ffffff; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px;">
            <h2 style="color: #1e3a8a; margin-top: 0;">Hello ${name || 'Leader'},</h2>
            
            <div style="background-color: #f0f9ff; padding: 20px; border-radius: 8px; border-left: 4px solid #2563eb; margin: 20px 0;">
              <h3 style="color: #1e3a8a; margin-top: 0;">Your Leadership Archetype</h3>
              <h2 style="color: #059669; font-size: 32px; margin: 10px 0;">${archetype}</h2>
            </div>

            <h3 style="color: #1e3a8a;">Your Framework Scores</h3>
            <div style="background-color: #f9fafb; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <div style="display: flex; justify-content: space-between; margin: 10px 0; padding: 10px; background-color: #ffffff; border-radius: 4px;">
                <strong>SUPPORT:</strong>
                <span style="color: #059669; font-weight: bold;">${supportScore}/5</span>
              </div>
              <div style="display: flex; justify-content: space-between; margin: 10px 0; padding: 10px; background-color: #ffffff; border-radius: 4px;">
                <strong>RESPONSIBLE:</strong>
                <span style="color: #059669; font-weight: bold;">${responsibleScore}/5</span>
              </div>
              <div style="display: flex; justify-content: space-between; margin: 10px 0; padding: 10px; background-color: #ffffff; border-radius: 4px;">
                <strong>SELFLESS:</strong>
                <span style="color: #059669; font-weight: bold;">${selflessScore}/5</span>
              </div>
              <div style="display: flex; justify-content: space-between; margin: 10px 0; padding: 10px; background-color: #ffffff; border-radius: 4px;">
                <strong>ACCOUNTABILITY:</strong>
                <span style="color: #059669; font-weight: bold;">${accountabilityScore}/5</span>
              </div>
            </div>

            ${recommendations ? `
            <h3 style="color: #1e3a8a;">Development Recommendations</h3>
            <div style="background-color: #fef3c7; padding: 20px; border-radius: 8px; margin: 20px 0;">
              ${recommendations}
            </div>
            ` : ''}

            <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; margin: 30px 0;">
              <h4 style="color: #374151; margin-top: 0;">Next Steps</h4>
              <ul style="color: #4b5563;">
                <li>Reflect on your results and identify areas for growth</li>
                <li>Share insights with your team or mentor</li>
                <li>Consider retaking the assessment in 6 months to track progress</li>
              </ul>
            </div>

            <p>Thank you for taking the TPEAINDEX Leadership Assessment. We're committed to helping you develop positive, effective leadership.</p>
            
            <p>Questions about your results? Contact us at support@tpeaindex.com</p>
          </div>

          <div style="text-align: center; padding: 20px; color: #6b7280; font-size: 12px; background-color: #f9fafb;">
            <p>TPEAINDEX Leadership Assessment<br>
            Empowering Positive Effect Leadership</p>
          </div>
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