-- ============================================================
-- FILE: data_cleaning.sql
-- PROJECT: Healthcare Claims Analytics Dashboard
-- PURPOSE: Rename columns, validate data quality, and build
--          the final analysis table with engineered features
-- ============================================================


-- STEP 1: Rename columns to remove spaces for SQL compatibility
-- ============================================================
CREATE TABLE claims_clean AS
SELECT
    "Claim ID"           AS claim_id,
    "Provider ID"        AS provider_id,
    "Patient ID"         AS patient_id,
    "Date of Service"    AS date_of_service,
    "Billed Amount"      AS billed_amount,
    "Procedure Code"     AS procedure_code,
    "Diagnosis Code"     AS diagnosis_code,
    "Allowed Amount"     AS allowed_amount,
    "Paid Amount"        AS paid_amount,
    "Insurance Type"     AS insurance_type,
    "Claim Status"       AS claim_status,
    "Reason Code"        AS reason_code,
    "Follow-up Required" AS follow_up_required,
    "AR Status"          AS ar_status,
    "Outcome"            AS outcome
FROM claims_raw;


-- STEP 2: Verify rename
-- ============================================================
SELECT * FROM claims_clean LIMIT 5;


-- STEP 3: Check for duplicate claim IDs
-- Each claim should be unique — duplicates would skew counts
-- ============================================================
SELECT claim_id, COUNT(*) AS occurrences
FROM claims_clean
GROUP BY claim_id
HAVING COUNT(*) > 1;


-- STEP 4: Check for missing values in critical columns
-- ============================================================
SELECT
    SUM(CASE WHEN claim_id       IS NULL THEN 1 ELSE 0 END) AS null_claim_id,
    SUM(CASE WHEN claim_status   IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN billed_amount  IS NULL THEN 1 ELSE 0 END) AS null_billed,
    SUM(CASE WHEN insurance_type IS NULL THEN 1 ELSE 0 END) AS null_payer,
    SUM(CASE WHEN reason_code    IS NULL THEN 1 ELSE 0 END) AS null_reason
FROM claims_clean;


-- STEP 5: Build final analysis table with engineered features
-- Date conversion: raw format is M/D/YYYY — converting to YYYY-MM-DD
-- for SQLite strftime compatibility
-- Denied amount and payment rate added for financial impact analysis
-- Preventable flag classifies denials by operational root cause
-- ============================================================
CREATE TABLE claims_final AS
SELECT
    claim_id,
    provider_id,
    patient_id,
    date_of_service,
    insurance_type,
    claim_status,
    reason_code,
    follow_up_required,
    ar_status,
    outcome,
    procedure_code,
    diagnosis_code,
    CAST(billed_amount  AS REAL) AS billed_amount,
    CAST(allowed_amount AS REAL) AS allowed_amount,
    CAST(paid_amount    AS REAL) AS paid_amount,
    CAST(billed_amount AS REAL) - CAST(paid_amount AS REAL) AS denied_amount,
    ROUND(100.0 * CAST(paid_amount AS REAL) / NULLIF(CAST(billed_amount AS REAL), 0), 2) AS payment_rate_pct,

    -- Convert M/D/YYYY to YYYY-MM-DD for strftime compatibility
    substr(date_of_service, -4) || '-' ||
    printf('%02d', CAST(substr(date_of_service, 1, instr(date_of_service, '/') - 1) AS INTEGER)) || '-' ||
    printf('%02d', CAST(substr(date_of_service, instr(date_of_service, '/') + 1,
        instr(substr(date_of_service, instr(date_of_service, '/') + 1), '/') - 1) AS INTEGER))
    AS service_date,

    CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END AS is_rejected,
    CASE WHEN claim_status = 'Paid'   THEN 1 ELSE 0 END AS is_approved,
    CASE WHEN follow_up_required = 'Yes' THEN 1 ELSE 0 END AS follow_up_flag,

    -- Preventable: admin/process errors correctable by operations
    -- Non-Preventable: clinical or policy reasons outside ops control
    CASE
        WHEN claim_status != 'Denied'                      THEN 'N/A'
        WHEN reason_code = 'Authorization not obtained'    THEN 'Preventable'
        WHEN reason_code = 'Duplicate claim'               THEN 'Preventable'
        WHEN reason_code = 'Incorrect billing information' THEN 'Preventable'
        WHEN reason_code = 'Missing documentation'         THEN 'Preventable'
        WHEN reason_code = 'Patient eligibility issues'    THEN 'Preventable'
        WHEN reason_code = 'Lack of medical necessity'     THEN 'Non-Preventable'
        WHEN reason_code = 'Pre-existing condition'        THEN 'Non-Preventable'
        WHEN reason_code = 'Service not covered'           THEN 'Non-Preventable'
        ELSE 'Non-Preventable'
    END AS preventable_flag,

    CASE
        WHEN CAST(billed_amount AS REAL) < 500    THEN 'Low (under $500)'
        WHEN CAST(billed_amount AS REAL) <= 2000  THEN 'Medium ($500-$2K)'
        WHEN CAST(billed_amount AS REAL) <= 10000 THEN 'High ($2K-$10K)'
        ELSE 'Very High (over $10K)'
    END AS claim_size_bucket

FROM claims_clean;


-- STEP 6: Add date dimension columns after service_date conversion
-- ============================================================
ALTER TABLE claims_final ADD COLUMN month_label TEXT;
ALTER TABLE claims_final ADD COLUMN claim_month INTEGER;
ALTER TABLE claims_final ADD COLUMN claim_year INTEGER;
ALTER TABLE claims_final ADD COLUMN claim_quarter TEXT;

UPDATE claims_final SET
    month_label   = strftime('%Y-%m', service_date),
    claim_month   = CAST(strftime('%m', service_date) AS INTEGER),
    claim_year    = CAST(strftime('%Y', service_date) AS INTEGER),
    claim_quarter = CASE
        WHEN CAST(strftime('%m', service_date) AS INTEGER) <= 3 THEN 'Q1'
        WHEN CAST(strftime('%m', service_date) AS INTEGER) <= 6 THEN 'Q2'
        WHEN CAST(strftime('%m', service_date) AS INTEGER) <= 9 THEN 'Q3'
        ELSE 'Q4'
    END;


-- STEP 7: Validate final output
-- ============================================================
SELECT
    COUNT(*)         AS total_rows,
    SUM(is_rejected) AS total_denied,
    SUM(is_approved) AS total_paid
FROM claims_final;
