// Stripe Webhook for Payment Link Fulfillment
// Handles checkout.session.completed events to generate codes and send emails

const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const sig = req.headers['stripe-signature'];
  const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;

  try {
    // Verify webhook signature
    event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).json({ error: 'Webhook signature verification failed' });
  }

  // Handle the checkout.session.completed event
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    
    try {
      await handleSuccessfulPayment(session);
      console.log('Payment fulfillment completed for session:', session.id);
    } catch (error) {
      console.error('Error handling successful payment:', error);
      return res.status(500).json({ error: 'Fulfillment failed' });
    }
  }

  res.status(200).json({ received: true });
}

async function handleSuccessfulPayment(session) {
  const {
    id: sessionId,
    customer_email: customerEmail,
    customer_details,
    amount_total,
    metadata,
    line_items
  } = session;

  // Get customer info
  const customerName = customer_details?.name || 'Customer';
  const amountPaid = amount_total / 100; // Convert from cents

  // Determine package size based on amount
  const packageDetails = getPackageDetails(amountPaid);
  
  console.log('Processing payment:', {
    sessionId,
    customerEmail,
    customerName,
    amountPaid,
    packageSize: packageDetails.size
  });

  // 1. Store purchase in database
  const { data: purchase, error: purchaseError } = await supabase
    .from('purchases')
    .insert({
      customer_email: customerEmail,
      customer_name: customerName,
      package_size: packageDetails.size,
      amount_paid: amountPaid,
      paypal_transaction_id: sessionId, // Using session_id as transaction ID
      status: 'completed'
    })
    .select()
    .single();

  if (purchaseError) {
    throw new Error('Failed to store purchase: ' + purchaseError.message);
  }

  // 2. Generate access codes
  const { data: codes, error: codesError } = await supabase
    .rpc('create_access_codes', {
      purchase_uuid: purchase.id,
      code_count: packageDetails.size
    });

  if (codesError) {
    throw new Error('Failed to generate codes: ' + codesError.message);
  }

  console.log('Generated codes:', codes);

  // 3. Send email with codes
  await sendEmailWithCodes(customerEmail, customerName, codes, packageDetails);

  // 4. Log email delivery
  await supabase
    .from('email_logs')
    .insert({
      purchase_id: purchase.id,
      recipient_email: customerEmail,
      email_type: 'purchase_confirmation',
      status: 'sent'
    });

  console.log('Email sent and logged for:', customerEmail);
}

function getPackageDetails(amountPaid) {
  // Map amounts to package sizes
  if (amountPaid >= 1400) return { size: 25, name: '25-Person Team Package' };
  if (amountPaid >= 750) return { size: 10, name: '10-Person Team Package' };
  if (amountPaid >= 400) return { size: 5, name: '5-Person Team Package' };
  return { size: 1, name: 'Individual Assessment' };
}

async function sendEmailWithCodes(customerEmail, customerName, codes, packageDetails) {
  // Using EmailJS REST API for server-side sending
  const emailjsUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  
  const codesList = codes.map((codeData, index) => {
    const code = typeof codeData === 'string' ? codeData : codeData.code;
    return `Code ${index + 1}: ${code}`;
  }).join('\n');

  const templateParams = {
    to_name: customerName,
    to_email: customerEmail,
    package_size: packageDetails.size,
    amount_paid: packageDetails.size * 97, // Calculate based on package
    codes_list: codesList,
    purchase_date: new Date().toLocaleDateString(),
    portal_link: 'https://www.thepositiveeffectindex.com/'
  };

  const emailData = {
    service_id: process.env.EMAILJS_SERVICE_ID,
    template_id: process.env.EMAILJS_TEMPLATE_ID,
    user_id: process.env.EMAILJS_PUBLIC_KEY,
    template_params: templateParams
  };

  try {
    const response = await fetch(emailjsUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(emailData)
    });

    if (!response.ok) {
      throw new Error(`EmailJS failed: ${response.status}`);
    }

    console.log('Email sent successfully via EmailJS');
  } catch (error) {
    console.error('Failed to send email:', error);
    throw error;
  }
}