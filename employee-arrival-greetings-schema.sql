-- ============================================================================
-- Employee Arrival Greetings - Database Schema
-- ============================================================================
-- This schema supports an automated employee greeting system that:
-- - Detects employees via WiFi MAC address presence
-- - Sends personalized AI-generated greetings via SMS
-- - Tracks greeting history to avoid repetition
-- - Records first arrival time each day
-- ============================================================================

-- ============================================================================
-- CONTACTS TABLE
-- ============================================================================
-- Main contacts table - you may already have this table. If so, just add
-- the is_employee and employee_mac columns.

CREATE TABLE IF NOT EXISTS contacts (
    contact_id SERIAL PRIMARY KEY,
    phone VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    company_name VARCHAR(255),
    notes TEXT,
    is_employee BOOLEAN DEFAULT FALSE,
    employee_mac VARCHAR(17),  -- WiFi MAC address format: xx:xx:xx:xx:xx:xx
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- If contacts table already exists, add the employee columns:
-- ALTER TABLE contacts ADD COLUMN IF NOT EXISTS is_employee BOOLEAN DEFAULT FALSE;
-- ALTER TABLE contacts ADD COLUMN IF NOT EXISTS employee_mac VARCHAR(17);

-- Index for quick employee lookups
CREATE INDEX IF NOT EXISTS idx_contacts_employee 
ON contacts(is_employee) 
WHERE is_employee = TRUE;

-- Index for MAC address lookups
CREATE INDEX IF NOT EXISTS idx_contacts_mac 
ON contacts(employee_mac) 
WHERE employee_mac IS NOT NULL;


-- ============================================================================
-- PRESENCE GREETINGS TABLE
-- ============================================================================
-- Tracks when employees were last greeted and their first arrival time each day

CREATE TABLE IF NOT EXISTS presence_greetings (
    contact_id INTEGER PRIMARY KEY REFERENCES contacts(contact_id) ON DELETE CASCADE,
    last_greeted DATE,                                    -- Date of last greeting sent
    last_seen_at TIMESTAMP WITH TIME ZONE,                -- Last time detected on WiFi
    first_seen_today TIMESTAMP WITH TIME ZONE             -- First arrival time today (resets daily)
);

-- Index for date-based queries
CREATE INDEX IF NOT EXISTS idx_presence_greetings_date 
ON presence_greetings(last_greeted);


-- ============================================================================
-- GREETING HISTORY TABLE
-- ============================================================================
-- Stores all greetings sent to avoid repetition

CREATE TABLE IF NOT EXISTS greeting_history (
    id SERIAL PRIMARY KEY,
    contact_id INTEGER REFERENCES contacts(contact_id) ON DELETE CASCADE,
    greeting_text TEXT,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for quick lookups of recent greetings per contact
CREATE INDEX IF NOT EXISTS idx_greeting_history_contact 
ON greeting_history(contact_id, sent_at DESC);


-- ============================================================================
-- PHONE NORMALIZATION FUNCTION (OPTIONAL BUT RECOMMENDED)
-- ============================================================================
-- Normalizes phone numbers to consistent format (10 digits, no formatting)

CREATE OR REPLACE FUNCTION normalize_phone(input TEXT)
RETURNS TEXT AS $$
DECLARE
    digits TEXT;
BEGIN
    IF input IS NULL OR input = '' THEN
        RETURN NULL;
    END IF;
    
    -- Strip all non-numeric characters
    digits := regexp_replace(input, '[^0-9]', '', 'g');
    
    -- Remove leading 1 if 11 digits (US country code)
    IF length(digits) = 11 AND digits LIKE '1%' THEN
        digits := substring(digits from 2);
    END IF;
    
    -- Validate: must be at least 10 digits
    IF length(digits) < 10 THEN
        RETURN NULL;
    END IF;
    
    RETURN digits;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ============================================================================
-- SAMPLE DATA (OPTIONAL)
-- ============================================================================
-- Example of adding an employee with MAC address

-- INSERT INTO contacts (phone, first_name, last_name, email, company_name, is_employee, employee_mac)
-- VALUES ('5551234567', 'John', 'Doe', 'john@example.com', 'Your Company', TRUE, 'aa:bb:cc:dd:ee:ff');


-- ============================================================================
-- USEFUL QUERIES
-- ============================================================================

-- View all employees with greeting status:
-- SELECT
--     c.contact_id,
--     c.first_name,
--     c.last_name,
--     c.phone,
--     c.employee_mac,
--     pg.last_greeted,
--     pg.last_seen_at AT TIME ZONE 'America/Los_Angeles' AS last_seen_pacific,
--     pg.first_seen_today AT TIME ZONE 'America/Los_Angeles' AS first_arrival_pacific,
--     CASE WHEN pg.last_greeted = CURRENT_DATE THEN 'YES' ELSE 'NO' END AS greeted_today
-- FROM contacts c
-- LEFT JOIN presence_greetings pg ON c.contact_id = pg.contact_id
-- WHERE c.is_employee = TRUE
-- ORDER BY c.first_name, c.last_name;

-- View today's greetings:
-- SELECT 
--     c.first_name,
--     c.last_name,
--     gh.greeting_text,
--     gh.sent_at AT TIME ZONE 'America/Los_Angeles' AS sent_at_pacific
-- FROM greeting_history gh
-- JOIN contacts c ON gh.contact_id = c.contact_id
-- WHERE gh.sent_at::DATE = CURRENT_DATE
-- ORDER BY gh.sent_at DESC;

-- View greeting history for a specific employee:
-- SELECT greeting_text, sent_at AT TIME ZONE 'America/Los_Angeles' AS sent_at_pacific
-- FROM greeting_history
-- WHERE contact_id = YOUR_CONTACT_ID
-- ORDER BY sent_at DESC
-- LIMIT 20;

-- Reset greeting for testing (replace YOUR_CONTACT_ID):
-- DELETE FROM presence_greetings WHERE contact_id = YOUR_CONTACT_ID;

-- Clear all presence data for fresh start:
-- TRUNCATE presence_greetings;
-- TRUNCATE greeting_history;
