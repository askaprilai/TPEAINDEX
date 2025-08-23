-- TPEAINDEX Database Schema for Supabase
-- Run this in Supabase SQL Editor

-- Company codes table for bulk purchases
CREATE TABLE company_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    purchase_type TEXT NOT NULL CHECK (purchase_type IN ('TEAM', 'COMPANY', 'ENTERPRISE', 'INDIVIDUAL')),
    total_licenses INTEGER NOT NULL DEFAULT 1,
    remaining_uses INTEGER NOT NULL,
    price_paid DECIMAL(10,2) NOT NULL,
    purchaser_email TEXT,
    company_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '1 year'),
    is_active BOOLEAN DEFAULT true
);

-- Assessment results table
CREATE TABLE assessment_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_code_id UUID REFERENCES company_codes(id) ON DELETE SET NULL,
    email TEXT NOT NULL,
    name TEXT,
    responses JSONB NOT NULL,
    scores JSONB NOT NULL,
    archetype TEXT,
    framework_scores JSONB,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT
);

-- Indexes for better performance
CREATE INDEX idx_company_codes_code ON company_codes(code);
CREATE INDEX idx_company_codes_active ON company_codes(is_active, expires_at);
CREATE INDEX idx_assessment_results_email ON assessment_results(email);
CREATE INDEX idx_assessment_results_completed ON assessment_results(completed_at);
CREATE INDEX idx_assessment_results_company_code ON assessment_results(company_code_id);

-- Row Level Security (RLS) policies
ALTER TABLE company_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_results ENABLE ROW LEVEL SECURITY;

-- Allow anonymous access for company code validation (read-only)
CREATE POLICY "Allow anonymous code validation" ON company_codes
    FOR SELECT
    TO anon
    USING (is_active = true AND expires_at > NOW());

-- Allow anonymous insertion of assessment results
CREATE POLICY "Allow anonymous assessment submission" ON assessment_results
    FOR INSERT
    TO anon
    WITH CHECK (true);

-- Allow reading assessment results by email (for results retrieval)
CREATE POLICY "Allow assessment results by email" ON assessment_results
    FOR SELECT
    TO anon
    USING (true);

-- Function to use a company code (decrements remaining_uses)
CREATE OR REPLACE FUNCTION use_company_code(code_input TEXT)
RETURNS TABLE(success BOOLEAN, message TEXT, code_data JSONB) AS $$
BEGIN
    -- Check if code exists and is valid
    IF NOT EXISTS (
        SELECT 1 FROM company_codes 
        WHERE code = code_input 
        AND is_active = true 
        AND expires_at > NOW() 
        AND remaining_uses > 0
    ) THEN
        RETURN QUERY SELECT false, 'Invalid or expired company code', NULL::JSONB;
        RETURN;
    END IF;

    -- Decrement the remaining uses
    UPDATE company_codes 
    SET remaining_uses = remaining_uses - 1
    WHERE code = code_input;

    -- Return success with code data
    RETURN QUERY 
    SELECT 
        true as success, 
        'Code validated successfully' as message,
        jsonb_build_object(
            'code', c.code,
            'purchase_type', c.purchase_type,
            'remaining_uses', c.remaining_uses,
            'company_name', c.company_name
        ) as code_data
    FROM company_codes c
    WHERE c.code = code_input;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create a new company code
CREATE OR REPLACE FUNCTION create_company_code(
    code_input TEXT,
    purchase_type_input TEXT,
    total_licenses_input INTEGER,
    price_paid_input DECIMAL,
    purchaser_email_input TEXT DEFAULT NULL,
    company_name_input TEXT DEFAULT NULL
)
RETURNS TABLE(success BOOLEAN, message TEXT, code_data JSONB) AS $$
BEGIN
    -- Insert the new company code
    INSERT INTO company_codes (
        code, 
        purchase_type, 
        total_licenses, 
        remaining_uses, 
        price_paid, 
        purchaser_email, 
        company_name
    ) VALUES (
        code_input,
        purchase_type_input,
        total_licenses_input,
        total_licenses_input,
        price_paid_input,
        purchaser_email_input,
        company_name_input
    );

    -- Return success with the created code data
    RETURN QUERY 
    SELECT 
        true,
        'Company code created successfully',
        jsonb_build_object(
            'code', code_input,
            'purchase_type', purchase_type_input,
            'total_licenses', total_licenses_input,
            'remaining_uses', total_licenses_input,
            'company_name', company_name_input
        );

EXCEPTION
    WHEN unique_violation THEN
        RETURN QUERY SELECT false, 'Company code already exists', NULL::JSONB;
    WHEN OTHERS THEN
        RETURN QUERY SELECT false, 'Error creating company code', NULL::JSONB;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON company_codes TO anon;
GRANT INSERT ON assessment_results TO anon;
GRANT EXECUTE ON FUNCTION use_company_code TO anon;
GRANT EXECUTE ON FUNCTION create_company_code TO anon;