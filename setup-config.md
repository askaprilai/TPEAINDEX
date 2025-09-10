# Enhanced Code Management System - Setup Guide

## 🛠️ **Required Credentials & Setup**

### **1. Supabase Database Setup**

#### **A. Create Supabase Project**
1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Copy your credentials:
   - Project URL: `https://your-project.supabase.co`
   - Anon Key: `eyJhbGc...` (public key)
   - Service Role Key: `eyJhbGc...` (private key - keep secure)

#### **B. Run Database Schema**
1. Open Supabase SQL Editor
2. Copy and paste entire contents of `supabase-schema.sql`
3. Execute the script to create all tables and functions

#### **C. Update index.html**
Replace these placeholders in `index.html`:
```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL'; // Your project URL
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY'; // Your anon key
```

### **2. EmailJS Setup (for automated emails)**

#### **A. Create EmailJS Account**
1. Go to [emailjs.com](https://emailjs.com)
2. Create free account (300 emails/month free)
3. Create email service (Gmail, Outlook, etc.)

#### **B. Create Email Template**
Template ID: `team_codes_template`
Template content:
```
Subject: Your Team Assessment Access Codes - {{package_size}} Members

Dear {{to_name}},

Thank you for your purchase! Your team assessment codes are ready.

Package Details:
- Team Size: {{package_size}} members  
- Amount Paid: ${{amount_paid}}
- Purchase Date: {{purchase_date}}

Your Access Codes:
{{codes_list}}

Instructions:
1. Share these codes with your team members
2. Each person visits: https://www.thepositiveeffectindex.com/
3. Enter their unique code when prompted
4. Complete the assessment

Need to access your codes again? Visit: {{portal_link}}

Best regards,
April Sabral
Positive Effect Leaders Assessment

---
This is an automated email. Please don't reply to this address.
```

#### **C. Update index.html**
Replace these placeholders:
```javascript
const EMAILJS_SERVICE_ID = 'YOUR_EMAILJS_SERVICE_ID';
const EMAILJS_TEMPLATE_ID = 'YOUR_EMAILJS_TEMPLATE_ID'; 
const EMAILJS_PUBLIC_KEY = 'YOUR_EMAILJS_PUBLIC_KEY';
```

### **3. Code Validation System**

Update the existing code validation to use database:
```javascript
// In validateCompanyCode function, add database check
async function validateCompanyCode() {
    const code = document.getElementById('companyCode').value.trim().toUpperCase();
    
    if (supabaseClient) {
        // Check database for valid code
        const { data, error } = await supabaseClient
            .rpc('use_access_code', {
                code_to_use: code,
                user_email: 'user@example.com', // Get from form
                user_name: 'User Name' // Get from form
            });
        
        if (data) {
            // Valid code - grant access
            document.getElementById('paymentGateway').style.display = 'none';
            document.getElementById('assessmentContent').style.display = 'block';
            alert('Access code validated! Welcome to your assessment.');
            return;
        }
    }
    
    // Fallback to static codes
    const validCodes = ['DEMO2024', 'CORPORATE', 'LEADERSHIP', 'TEAM2024', 'COMPANY'];
    // ... rest of existing logic
}
```

## 📧 **Email Template Variables**

Available variables for your EmailJS template:
- `{{to_name}}` - Customer name
- `{{to_email}}` - Customer email  
- `{{package_size}}` - Number of codes (5, 10, 25)
- `{{amount_paid}}` - Purchase amount
- `{{codes_list}}` - Comma-separated list of codes
- `{{portal_link}}` - Link to customer portal
- `{{purchase_date}}` - Date of purchase

## 🔒 **Security Notes**

1. **Never commit sensitive keys** to git
2. **Use environment variables** for production
3. **Enable RLS** on all Supabase tables (already included in schema)
4. **Rotate keys** if compromised

## 📊 **Database Tables Created**

- `purchases` - Stores group purchase information
- `access_codes` - Individual team member codes
- `assessment_results` - Completed assessment data  
- `email_logs` - Email delivery tracking

## 🚀 **Features Enabled**

✅ **Professional Success Page** - No more popups  
✅ **PDF Generation** - Branded, downloadable codes  
✅ **Database Storage** - Never lose codes again  
✅ **Code Recovery** - Customer portal access  
✅ **Usage Tracking** - See who completed assessments  
✅ **Email Automation** - Professional delivery system  
✅ **Fallback System** - Works even if services are down

## 🔧 **Testing**

1. **Test Group Purchase** - Buy 5-person package
2. **Check Database** - Verify purchase and codes stored
3. **Test PDF** - Download generated PDF
4. **Test Email** - Check email delivery
5. **Test Code Usage** - Validate codes work on site

## 📞 **Support**

If you need help with setup:
1. Check browser console for errors
2. Verify all credentials are correct
3. Test each component individually
4. Check Supabase logs for database errors

## 🎯 **Next Steps**

1. Set up Supabase project and run schema
2. Configure EmailJS for automated emails  
3. Update credentials in index.html
4. Test the system with a small purchase
5. Launch enhanced system to customers!