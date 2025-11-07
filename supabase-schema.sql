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
    stripe_transaction_id VARCHAR(255) UNIQUE,
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

-- Client profiles table - stores unique client information and tracks progression
CREATE TABLE client_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    company VARCHAR(255),
    role_title VARCHAR(255),
    first_assessment_date TIMESTAMP WITH TIME ZONE,
    last_assessment_date TIMESTAMP WITH TIME ZONE,
    total_assessments INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Assessment results table - stores completed assessment data with client history
CREATE TABLE assessment_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_profile_id UUID REFERENCES client_profiles(id) ON DELETE CASCADE,
    code_id UUID REFERENCES access_codes(id) ON DELETE CASCADE,
    user_email VARCHAR(255),
    user_name VARCHAR(255),
    scores JSONB, -- stores the leadership dimension scores
    responses JSONB, -- stores all question responses
    personalization_data JSONB, -- stores personalization context
    assessment_type VARCHAR(50) DEFAULT 'individual', -- 'individual', 'team', 'follow_up'
    assessment_version VARCHAR(20) DEFAULT '1.0',
    completion_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Assessment progression table - tracks score changes over time
CREATE TABLE assessment_progression (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_profile_id UUID REFERENCES client_profiles(id) ON DELETE CASCADE,
    current_assessment_id UUID REFERENCES assessment_results(id) ON DELETE CASCADE,
    previous_assessment_id UUID REFERENCES assessment_results(id) ON DELETE SET NULL,
    dimension_name VARCHAR(100), -- 'performance', 'relationship', 'communication', etc.
    current_score INTEGER,
    previous_score INTEGER,
    score_change INTEGER, -- calculated: current_score - previous_score
    percentage_change DECIMAL(5,2), -- calculated percentage change
    improvement_direction VARCHAR(20), -- 'improved', 'declined', 'maintained'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Development recommendations table - tracks coaching recommendations over time
CREATE TABLE development_recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_profile_id UUID REFERENCES client_profiles(id) ON DELETE CASCADE,
    assessment_result_id UUID REFERENCES assessment_results(id) ON DELETE CASCADE,
    dimension VARCHAR(100),
    recommendation_text TEXT,
    priority_level VARCHAR(20), -- 'high', 'medium', 'low'
    status VARCHAR(50) DEFAULT 'active', -- 'active', 'completed', 'superseded'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
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

-- Coach profiles table - stores coach/affiliate information
CREATE TABLE coach_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    company VARCHAR(255),
    phone VARCHAR(50),
    website VARCHAR(500),
    experience_level VARCHAR(50), -- 'new', 'emerging', 'experienced', 'seasoned'
    client_base_size VARCHAR(20), -- '1-5', '6-15', '16-30', '31-50', '50+'
    specialization VARCHAR(500),
    motivation TEXT,
    referral_source VARCHAR(100),
    
    -- Payment & Stripe Connect Info
    stripe_account_id VARCHAR(255) UNIQUE,
    payment_status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'connected', 'restricted', 'rejected'
    onboarding_completed BOOLEAN DEFAULT FALSE,
    charges_enabled BOOLEAN DEFAULT FALSE,
    payouts_enabled BOOLEAN DEFAULT FALSE,
    
    -- Commission Settings
    commission_rate DECIMAL(5,2) DEFAULT 25.00, -- 25% default
    minimum_payout DECIMAL(10,2) DEFAULT 50.00, -- $50 minimum
    payout_schedule VARCHAR(20) DEFAULT 'weekly', -- 'weekly', 'monthly'
    
    -- Status & Tracking
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'approved', 'active', 'suspended'
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by VARCHAR(255),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Commission transactions table - tracks all commission earnings
CREATE TABLE commission_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    coach_profile_id UUID REFERENCES coach_profiles(id) ON DELETE CASCADE,
    purchase_id UUID REFERENCES purchases(id) ON DELETE CASCADE,
    
    -- Transaction Details
    gross_amount DECIMAL(10,2) NOT NULL, -- Original purchase amount
    commission_rate DECIMAL(5,2) NOT NULL, -- Rate applied (25%, 30%, etc.)
    commission_amount DECIMAL(10,2) NOT NULL, -- Calculated commission
    
    -- Status Tracking
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'approved', 'paid', 'disputed'
    approved_at TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE,
    
    -- Payout Information
    payout_batch_id VARCHAR(255), -- Stripe payout batch reference
    stripe_transfer_id VARCHAR(255), -- Individual transfer ID
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payout batches table - tracks batch payouts to coaches
CREATE TABLE payout_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    total_amount DECIMAL(12,2) NOT NULL,
    total_coaches INTEGER NOT NULL,
    total_transactions INTEGER NOT NULL,
    
    -- Stripe Information
    stripe_batch_id VARCHAR(255),
    
    -- Processing Details
    processed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX idx_purchases_email ON purchases(customer_email);
CREATE INDEX idx_purchases_transaction ON purchases(stripe_transaction_id);
CREATE INDEX idx_access_codes_purchase ON access_codes(purchase_id);
CREATE INDEX idx_access_codes_code ON access_codes(code);
CREATE INDEX idx_access_codes_used ON access_codes(is_used);
CREATE INDEX idx_assessment_results_code ON assessment_results(code_id);
CREATE INDEX idx_assessment_results_client ON assessment_results(client_profile_id);
CREATE INDEX idx_assessment_results_email ON assessment_results(user_email);
CREATE INDEX idx_assessment_results_date ON assessment_results(completion_date);
CREATE INDEX idx_client_profiles_email ON client_profiles(email);
CREATE INDEX idx_assessment_progression_client ON assessment_progression(client_profile_id);
CREATE INDEX idx_assessment_progression_dimension ON assessment_progression(dimension_name);
CREATE INDEX idx_development_recommendations_client ON development_recommendations(client_profile_id);
CREATE INDEX idx_development_recommendations_status ON development_recommendations(status);
CREATE INDEX idx_email_logs_purchase ON email_logs(purchase_id);
CREATE INDEX idx_coach_profiles_email ON coach_profiles(email);
CREATE INDEX idx_coach_profiles_stripe_account ON coach_profiles(stripe_account_id);
CREATE INDEX idx_coach_profiles_status ON coach_profiles(status);
CREATE INDEX idx_commission_transactions_coach ON commission_transactions(coach_profile_id);
CREATE INDEX idx_commission_transactions_purchase ON commission_transactions(purchase_id);
CREATE INDEX idx_commission_transactions_status ON commission_transactions(status);
CREATE INDEX idx_payout_batches_date ON payout_batches(batch_date);
CREATE INDEX idx_payout_batches_status ON payout_batches(status);

-- Row Level Security (RLS) policies
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_progression ENABLE ROW LEVEL SECURITY;
ALTER TABLE development_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_batches ENABLE ROW LEVEL SECURITY;

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

-- Policy: Users can view their own client profile
CREATE POLICY "Users can view own profile" ON client_profiles
    FOR SELECT USING (email = auth.jwt() ->> 'email');

-- Policy: Users can view their assessment results
CREATE POLICY "Users can view own results" ON assessment_results
    FOR SELECT USING (user_email = auth.jwt() ->> 'email');

-- Policy: Users can view their assessment progression
CREATE POLICY "Users can view own progression" ON assessment_progression
    FOR SELECT USING (
        client_profile_id IN (
            SELECT id FROM client_profiles WHERE email = auth.jwt() ->> 'email'
        )
    );

-- Policy: Users can view their development recommendations
CREATE POLICY "Users can view own recommendations" ON development_recommendations
    FOR SELECT USING (
        client_profile_id IN (
            SELECT id FROM client_profiles WHERE email = auth.jwt() ->> 'email'
        )
    );

-- Policy: Coaches can view and update their own profile
CREATE POLICY "Coaches can view own profile" ON coach_profiles
    FOR SELECT USING (email = auth.jwt() ->> 'email');

CREATE POLICY "Coaches can update own profile" ON coach_profiles
    FOR UPDATE USING (email = auth.jwt() ->> 'email');

-- Policy: Coaches can view their own commission transactions
CREATE POLICY "Coaches can view own commissions" ON commission_transactions
    FOR SELECT USING (
        coach_profile_id IN (
            SELECT id FROM coach_profiles WHERE email = auth.jwt() ->> 'email'
        )
    );

-- Policy: Only admin can view payout batches
CREATE POLICY "Admin can view payout batches" ON payout_batches
    FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');

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

-- Function to create or update client profile and track assessment history
CREATE OR REPLACE FUNCTION create_or_update_client_profile(
    user_email VARCHAR(255),
    user_name VARCHAR(255) DEFAULT NULL,
    user_company VARCHAR(255) DEFAULT NULL,
    user_role VARCHAR(255) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    client_id UUID;
    name_parts TEXT[];
    first_name VARCHAR(255);
    last_name VARCHAR(255);
BEGIN
    -- Parse name into first and last
    IF user_name IS NOT NULL THEN
        name_parts := string_to_array(trim(user_name), ' ');
        first_name := name_parts[1];
        IF array_length(name_parts, 1) > 1 THEN
            last_name := array_to_string(name_parts[2:], ' ');
        END IF;
    END IF;
    
    -- Insert or update client profile
    INSERT INTO client_profiles (email, first_name, last_name, company, role_title, first_assessment_date, last_assessment_date, total_assessments)
    VALUES (user_email, first_name, last_name, user_company, user_role, NOW(), NOW(), 1)
    ON CONFLICT (email) 
    DO UPDATE SET 
        last_assessment_date = NOW(),
        total_assessments = client_profiles.total_assessments + 1,
        first_name = COALESCE(EXCLUDED.first_name, client_profiles.first_name),
        last_name = COALESCE(EXCLUDED.last_name, client_profiles.last_name),
        company = COALESCE(EXCLUDED.company, client_profiles.company),
        role_title = COALESCE(EXCLUDED.role_title, client_profiles.role_title),
        updated_at = NOW()
    RETURNING id INTO client_id;
    
    RETURN client_id;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate and store assessment progression
CREATE OR REPLACE FUNCTION calculate_assessment_progression(
    current_assessment_id UUID,
    client_id UUID,
    current_scores JSONB
)
RETURNS VOID AS $$
DECLARE
    previous_assessment RECORD;
    dimension_name TEXT;
    current_score INTEGER;
    previous_score INTEGER;
    score_change INTEGER;
    percentage_change DECIMAL(5,2);
    improvement_direction VARCHAR(20);
BEGIN
    -- Find the most recent previous assessment for this client
    SELECT id, scores INTO previous_assessment
    FROM assessment_results 
    WHERE client_profile_id = client_id 
    AND id != current_assessment_id
    ORDER BY completion_date DESC 
    LIMIT 1;
    
    -- If no previous assessment, no progression to calculate
    IF previous_assessment IS NULL THEN
        RETURN;
    END IF;
    
    -- Calculate progression for each dimension
    FOR dimension_name IN SELECT jsonb_object_keys(current_scores)
    LOOP
        current_score := (current_scores ->> dimension_name)::INTEGER;
        previous_score := (previous_assessment.scores ->> dimension_name)::INTEGER;
        
        -- Skip if either score is null
        IF current_score IS NULL OR previous_score IS NULL THEN
            CONTINUE;
        END IF;
        
        score_change := current_score - previous_score;
        
        -- Calculate percentage change
        IF previous_score > 0 THEN
            percentage_change := (score_change::DECIMAL / previous_score::DECIMAL) * 100;
        ELSE
            percentage_change := 0;
        END IF;
        
        -- Determine improvement direction
        IF score_change > 0 THEN
            improvement_direction := 'improved';
        ELSIF score_change < 0 THEN
            improvement_direction := 'declined';
        ELSE
            improvement_direction := 'maintained';
        END IF;
        
        -- Insert progression record
        INSERT INTO assessment_progression (
            client_profile_id,
            current_assessment_id,
            previous_assessment_id,
            dimension_name,
            current_score,
            previous_score,
            score_change,
            percentage_change,
            improvement_direction
        ) VALUES (
            client_id,
            current_assessment_id,
            previous_assessment.id,
            dimension_name,
            current_score,
            previous_score,
            score_change,
            percentage_change,
            improvement_direction
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to generate development recommendations based on scores
CREATE OR REPLACE FUNCTION generate_development_recommendations(
    client_id UUID,
    assessment_id UUID,
    scores JSONB
)
RETURNS VOID AS $$
DECLARE
    dimension_name TEXT;
    score INTEGER;
    recommendation_text TEXT;
    priority_level VARCHAR(20);
BEGIN
    -- Mark previous recommendations as superseded
    UPDATE development_recommendations 
    SET status = 'superseded' 
    WHERE client_profile_id = client_id AND status = 'active';
    
    -- Generate new recommendations based on scores
    FOR dimension_name IN SELECT jsonb_object_keys(scores)
    LOOP
        score := (scores ->> dimension_name)::INTEGER;
        
        -- Skip if score is null
        IF score IS NULL THEN
            CONTINUE;
        END IF;
        
        -- Generate recommendations based on score ranges
        IF score < 60 THEN
            priority_level := 'high';
            CASE dimension_name
                WHEN 'performance' THEN
                    recommendation_text := 'Focus on goal-setting and KPI alignment. Practice regular performance conversations and create clear development plans.';
                WHEN 'relationship' THEN
                    recommendation_text := 'Develop psychological safety skills. Practice active listening and work on building stronger team connections.';
                WHEN 'communication' THEN
                    recommendation_text := 'Enhance empathy and positive-intent communication. Focus on deepening connection skills in difficult conversations.';
                WHEN 'coaching' THEN
                    recommendation_text := 'Develop coaching conversation skills. Practice asking profound questions and listening to learn rather than respond.';
                WHEN 'ownership' THEN
                    recommendation_text := 'Strengthen accountability practices. Set crystal-clear expectations and improve follow-up consistency.';
                WHEN 'mindset' THEN
                    recommendation_text := 'Focus on energy management and maintaining calm under pressure. Develop resilience and optimism practices.';
                ELSE
                    recommendation_text := 'Focus on developing foundational leadership skills in this area.';
            END CASE;
        ELSIF score < 80 THEN
            priority_level := 'medium';
            recommendation_text := 'Continue building on existing strengths in ' || dimension_name || '. Focus on consistency and advanced skill development.';
        ELSE
            priority_level := 'low';
            recommendation_text := 'Excellent performance in ' || dimension_name || '. Consider mentoring others and sharing best practices.';
        END IF;
        
        -- Insert recommendation
        INSERT INTO development_recommendations (
            client_profile_id,
            assessment_result_id,
            dimension,
            recommendation_text,
            priority_level
        ) VALUES (
            client_id,
            assessment_id,
            dimension_name,
            recommendation_text,
            priority_level
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to create or update coach profile from application
CREATE OR REPLACE FUNCTION create_coach_profile(
    coach_email VARCHAR(255),
    coach_first_name VARCHAR(255),
    coach_last_name VARCHAR(255),
    coach_phone VARCHAR(50) DEFAULT NULL,
    coach_company VARCHAR(255) DEFAULT NULL,
    coach_website VARCHAR(500) DEFAULT NULL,
    coach_experience VARCHAR(50) DEFAULT NULL,
    coach_client_base VARCHAR(20) DEFAULT NULL,
    coach_specialization VARCHAR(500) DEFAULT NULL,
    coach_motivation TEXT DEFAULT NULL,
    coach_referral_source VARCHAR(100) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    coach_id UUID;
BEGIN
    -- Insert new coach profile
    INSERT INTO coach_profiles (
        email, first_name, last_name, phone, company, website,
        experience_level, client_base_size, specialization, 
        motivation, referral_source, status
    )
    VALUES (
        coach_email, coach_first_name, coach_last_name, coach_phone, 
        coach_company, coach_website, coach_experience, coach_client_base,
        coach_specialization, coach_motivation, coach_referral_source, 'pending'
    )
    ON CONFLICT (email) 
    DO UPDATE SET 
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        phone = COALESCE(EXCLUDED.phone, coach_profiles.phone),
        company = COALESCE(EXCLUDED.company, coach_profiles.company),
        website = COALESCE(EXCLUDED.website, coach_profiles.website),
        experience_level = COALESCE(EXCLUDED.experience_level, coach_profiles.experience_level),
        client_base_size = COALESCE(EXCLUDED.client_base_size, coach_profiles.client_base_size),
        specialization = COALESCE(EXCLUDED.specialization, coach_profiles.specialization),
        motivation = COALESCE(EXCLUDED.motivation, coach_profiles.motivation),
        referral_source = COALESCE(EXCLUDED.referral_source, coach_profiles.referral_source),
        updated_at = NOW()
    RETURNING id INTO coach_id;
    
    RETURN coach_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update coach Stripe Connect status
CREATE OR REPLACE FUNCTION update_coach_stripe_status(
    coach_id UUID,
    stripe_account_id VARCHAR(255),
    payment_status VARCHAR(50),
    onboarding_completed BOOLEAN DEFAULT FALSE,
    charges_enabled BOOLEAN DEFAULT FALSE,
    payouts_enabled BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE coach_profiles 
    SET 
        stripe_account_id = update_coach_stripe_status.stripe_account_id,
        payment_status = update_coach_stripe_status.payment_status,
        onboarding_completed = update_coach_stripe_status.onboarding_completed,
        charges_enabled = update_coach_stripe_status.charges_enabled,
        payouts_enabled = update_coach_stripe_status.payouts_enabled,
        updated_at = NOW()
    WHERE id = update_coach_stripe_status.coach_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate and record commission transaction
CREATE OR REPLACE FUNCTION record_commission_transaction(
    coach_email VARCHAR(255),
    purchase_uuid UUID,
    gross_amount DECIMAL(10,2),
    commission_rate DECIMAL(5,2) DEFAULT 25.00
)
RETURNS UUID AS $$
DECLARE
    coach_id UUID;
    commission_amount DECIMAL(10,2);
    transaction_id UUID;
BEGIN
    -- Get coach ID
    SELECT id INTO coach_id FROM coach_profiles WHERE email = coach_email AND status = 'active';
    
    IF coach_id IS NULL THEN
        RETURN NULL; -- Coach not found or not active
    END IF;
    
    -- Calculate commission
    commission_amount := (gross_amount * commission_rate / 100);
    
    -- Insert commission transaction
    INSERT INTO commission_transactions (
        coach_profile_id,
        purchase_id,
        gross_amount,
        commission_rate,
        commission_amount,
        status
    )
    VALUES (
        coach_id,
        purchase_uuid,
        gross_amount,
        commission_rate,
        commission_amount,
        'pending'
    )
    RETURNING id INTO transaction_id;
    
    RETURN transaction_id;
END;
$$ LANGUAGE plpgsql;

-- Function to process weekly payouts
CREATE OR REPLACE FUNCTION create_weekly_payout_batch()
RETURNS UUID AS $$
DECLARE
    batch_id UUID;
    batch_total DECIMAL(12,2);
    coach_count INTEGER;
    transaction_count INTEGER;
BEGIN
    -- Calculate totals for pending commissions
    SELECT 
        COALESCE(SUM(commission_amount), 0),
        COUNT(DISTINCT coach_profile_id),
        COUNT(*)
    INTO batch_total, coach_count, transaction_count
    FROM commission_transactions ct
    JOIN coach_profiles cp ON ct.coach_profile_id = cp.id
    WHERE ct.status = 'approved' 
    AND cp.payouts_enabled = TRUE
    AND ct.commission_amount >= cp.minimum_payout;
    
    IF batch_total > 0 THEN
        -- Create payout batch
        INSERT INTO payout_batches (
            batch_date,
            total_amount,
            total_coaches,
            total_transactions,
            status
        )
        VALUES (
            CURRENT_DATE,
            batch_total,
            coach_count,
            transaction_count,
            'pending'
        )
        RETURNING id INTO batch_id;
        
        -- Update commission transactions to reference this batch
        UPDATE commission_transactions 
        SET payout_batch_id = batch_id::VARCHAR
        WHERE status = 'approved'
        AND coach_profile_id IN (
            SELECT cp.id FROM coach_profiles cp 
            WHERE cp.payouts_enabled = TRUE
        );
    END IF;
    
    RETURN batch_id;
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

-- Create views for easy client progression analysis
CREATE OR REPLACE VIEW client_progression_summary AS
SELECT 
    cp.email,
    cp.first_name,
    cp.last_name,
    cp.company,
    cp.total_assessments,
    cp.first_assessment_date,
    cp.last_assessment_date,
    EXTRACT(DAYS FROM cp.last_assessment_date - cp.first_assessment_date) as days_between_assessments,
    -- Latest scores
    (ar.scores->>'performance')::INTEGER as latest_performance,
    (ar.scores->>'relationship')::INTEGER as latest_relationship,
    (ar.scores->>'communication')::INTEGER as latest_communication,
    (ar.scores->>'coaching')::INTEGER as latest_coaching,
    (ar.scores->>'ownership')::INTEGER as latest_ownership,
    (ar.scores->>'mindset')::INTEGER as latest_mindset
FROM client_profiles cp
LEFT JOIN assessment_results ar ON ar.client_profile_id = cp.id 
    AND ar.completion_date = cp.last_assessment_date
ORDER BY cp.last_assessment_date DESC;

-- View for tracking dimension improvements
CREATE OR REPLACE VIEW dimension_improvements AS
SELECT 
    cp.email,
    cp.first_name,
    cp.last_name,
    ap.dimension_name,
    ap.current_score,
    ap.previous_score,
    ap.score_change,
    ap.percentage_change,
    ap.improvement_direction,
    ap.created_at as assessment_date
FROM assessment_progression ap
JOIN client_profiles cp ON cp.id = ap.client_profile_id
ORDER BY ap.created_at DESC, ap.percentage_change DESC;