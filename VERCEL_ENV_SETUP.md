# Vercel Environment Variables Setup

## Required Environment Variables for Launch

Copy these exact values to your Vercel dashboard under **Settings > Environment Variables**:

### Stripe Configuration
```
STRIPE_SECRET_KEY=sk_live_[YOUR_STRIPE_SECRET_KEY]
STRIPE_WEBHOOK_SECRET=whsec_[YOUR_WEBHOOK_SECRET]
```

### Supabase Configuration  
```
SUPABASE_URL=https://lfvsexynfvbtveuejeeq.supabase.co
SUPABASE_SERVICE_ROLE_KEY=[YOUR_SUPABASE_SERVICE_ROLE_KEY]
```

### EmailJS Configuration (for webhook fallback emails)
```
EMAILJS_SERVICE_ID=service_vntq4ai
EMAILJS_TEMPLATE_ID=template_s1qs194
EMAILJS_PUBLIC_KEY=SAU17WFhPmeQLrng7
```

### Resend API Key (for Supabase functions)
```
RESEND_API_KEY=YOUR_RESEND_API_KEY_HERE
```

## How to Set Up in Vercel:

1. Go to your Vercel dashboard
2. Select your TPEAINDEX project
3. Go to Settings > Environment Variables
4. Add each variable above with Name and Value
5. Set Environment to "Production" (or All if you want it in preview too)
6. Click "Save"

## Status:

1. ✅ **STRIPE_SECRET_KEY** - CONFIGURED
2. ✅ **SUPABASE_SERVICE_ROLE_KEY** - CONFIGURED
3. ⚠️ **RESEND_API_KEY** - Optional for backup emails (can add later)

## Test After Setup:

1. Deploy to Vercel
2. Test a $97 individual purchase
3. Verify webhook receives payment
4. Check codes are generated in Supabase
5. Confirm email delivery works

Your webhook secret is already configured: `whsec_YFBHGdxl8oywy61gDbwykogsOzbOFt3V`