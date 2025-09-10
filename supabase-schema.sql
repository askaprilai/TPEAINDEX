-- Supabase Database Schema for Positive Effect Leaders Assessment
-- Run this in your Supabase SQL editor

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Purchases table - stores group purchase information
CREATE TABLE purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_email VARCHAR(255) NOT NULL,
    customer_name VARCHAR(255),
    package_size INTEGER NOT NULL, -- 5, 10, or 25
    amount_paid DECIMAL(10,2) NOT NULL,
    purchase_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paypal_transaction_id VARCHAR(255) UNIQUE,
    status VARCHAR(50) DEFAULT 'completed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Access codes table - stores individual team access codes
CREATE TABLE access_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_id UUID REFERENCES purchases(id) ON DELETE CASCADE,
    code VARCHAR(12) UNIQUE NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    used_by_email VARCHAR(255),
    used_by_name VARCHAR(255),
    used_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '1 year')
);

-- Assessment results table - stores completed assessment data
CREATE TABLE assessment_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code_id UUID REFERENCES access_codes(id) ON DELETE CASCADE,
    user_email VARCHAR(255),
    user_name VARCHAR(255),
    scores JSONB, -- stores the leadership dimension scores
    responses JSONB, -- stores all question responses
    completion_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Email logs table - tracks email delivery
CREATE TABLE email_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_id UUID REFERENCES purchases(id) ON DELETE CASCADE,
    recipient_email VARCHAR(255) NOT NULL,
    email_type VARCHAR(50), -- 'purchase_confirmation', 'team_invite', 'reminder'
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'sent', -- 'sent', 'failed', 'bounced'
    email_content TEXT
);

-- Indexes for better performance
CREATE INDEX idx_purchases_email ON purchases(customer_email);
CREATE INDEX idx_purchases_transaction ON purchases(paypal_transaction_id);
CREATE INDEX idx_access_codes_purchase ON access_codes(purchase_id);
CREATE INDEX idx_access_codes_code ON access_codes(code);
CREATE INDEX idx_access_codes_used ON access_codes(is_used);
CREATE INDEX idx_assessment_results_code ON assessment_results(code_id);
CREATE INDEX idx_email_logs_purchase ON email_logs(purchase_id);

-- Row Level Security (RLS) policies
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own purchases
CREATE POLICY "Users can view own purchases" ON purchases
    FOR SELECT USING (customer_email = auth.jwt() ->> 'email');

-- Policy: Users can view codes from their purchases
CREATE POLICY "Users can view own codes" ON access_codes
    FOR SELECT USING (
        purchase_id IN (
            SELECT id FROM purchases WHERE customer_email = auth.jwt() ->> 'email'
        )
    );

-- Policy: Users can update codes they use
CREATE POLICY "Users can use access codes" ON access_codes
    FOR UPDATE USING (NOT is_used);

-- Policy: Users can view their assessment results
CREATE POLICY "Users can view own results" ON assessment_results
    FOR SELECT USING (user_email = auth.jwt() ->> 'email');

-- Functions for code generation and validation
CREATE OR REPLACE FUNCTION generate_unique_code()
RETURNS VARCHAR(12) AS $$
DECLARE
    new_code VARCHAR(12);
    code_exists BOOLEAN;
BEGIN
    LOOP
        -- Generate 8-character alphanumeric code
        new_code := UPPER(
            SUBSTR(
                encode(gen_random_bytes(6), 'base64'),
                1, 8
            )
        );
        
        -- Remove potentially confusing characters
        new_code := REPLACE(new_code, '0', 'A');
        new_code := REPLACE(new_code, 'O', 'B');
        new_code := REPLACE(new_code, 'I', 'C');
        new_code := REPLACE(new_code, 'L', 'D');
        new_code := REPLACE(new_code, '1', 'E');
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM access_codes WHERE code = new_code) INTO code_exists;
        
        IF NOT code_exists THEN
            RETURN new_code;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to create access codes for a purchase
CREATE OR REPLACE FUNCTION create_access_codes(purchase_uuid UUID, code_count INTEGER)
RETURNS TABLE(code VARCHAR(12)) AS $$
DECLARE
    i INTEGER;
    new_code VARCHAR(12);
BEGIN
    FOR i IN 1..code_count LOOP
        new_code := generate_unique_code();
        
        INSERT INTO access_codes (purchase_id, code)
        VALUES (purchase_uuid, new_code);
        
        RETURN NEXT new_code;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to validate and use access code
CREATE OR REPLACE FUNCTION use_access_code(
    code_to_use VARCHAR(12), 
    user_email VARCHAR(255), 
    user_name VARCHAR(255) DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    code_record RECORD;
BEGIN
    -- Find the code and check if it's valid
    SELECT * INTO code_record 
    FROM access_codes 
    WHERE code = code_to_use 
    AND NOT is_used 
    AND expires_at > NOW();
    
    IF code_record IS NULL THEN
        RETURN FALSE; -- Code not found, already used, or expired
    END IF;
    
    -- Mark code as used
    UPDATE access_codes 
    SET 
        is_used = TRUE,
        used_by_email = user_email,
        used_by_name = user_name,
        used_date = NOW()
    WHERE id = code_record.id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Create admin role for managing the system
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'assessment_admin') THEN
        CREATE ROLE assessment_admin;
    END IF;
END
$$;

-- Grant permissions to admin role
GRANT ALL ON ALL TABLES IN SCHEMA public TO assessment_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO assessment_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO assessment_admin;