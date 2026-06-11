-- ============================================================
-- FILE: data_cleaning.sql
-- PROJECT: Healthcare Claims Analytics Dashboard
-- PURPOSE: Take the raw imported data, rename columns to remove
--          spaces, check data quality, and create a final clean
--          table with extra columns for analysis
-- ============================================================


-- STEP 1: Rename columns
-- The original CSV has column names with spaces like "Claim ID"
-- SQL works much better with underscores like claim_id
-- So we create a new table called claims_clean with clean names
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


-- STEP 2: Preview the renamed table
-- Just a sanity check to make sure the rename worked correctly
-- ============================================================
SELECT * FROM claims_clean LIMIT 5;


-- STEP 3: Check for duplicate claim IDs
-- Every claim should have a unique ID
-- If any claim_id appears more than once, something is wrong
-- A result of 0 rows means no duplicates — which is what we want
-- ============================================================
SELECT claim_id, COUNT(*) AS occurrences
FROM claims_clean
GROUP BY claim_id
HAVING COUNT(*) > 1;


-- STEP 4: Check for missing values
-- We check the most important columns for NULL (empty) values
-- A result of 0 across all columns means the data is complete
-- ============================================================
SELECT
    SUM(CASE WHEN claim_id       IS NULL THEN 1 ELSE 0 END) AS null_claim_id,
    SUM(CASE WHEN claim_status   IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN billed_amount  IS NULL THEN 1 ELSE 0 END) AS null_billed,
    SUM(CASE WHEN insurance_type IS NULL THEN 1 ELSE 0 END) AS null_payer,
    SUM(CASE WHEN reason_code    IS NULL THEN 1 ELSE 0 END) AS null_reason
FROM claims_clean;


-- STEP 5: Create the final analysis table
-- This is the main step. We take claims_clean and add new columns
-- that we need for the dashboard — things like denied_amount,
-- month/quarter labels, and flags for rejected/approved claims
-- ============================================================
CREATE TABLE claims_final AS
SELECT
    -- Original columns carried over as-is
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

    -- Financial columns converted to numbers (REAL = decimal number)
    CAST(billed_amount  AS REAL) AS billed_amount,
    CAST(allowed_amount AS REAL) AS allowed_amount,
    CAST(paid_amount    AS REAL) AS paid_amount,

    -- How much was NOT paid (billed minus what was actually paid)
    CAST(billed_amount AS REAL) - CAST(paid_amount AS REAL) AS denied_amount,

    -- What percentage of the billed amount was paid
    ROUND(100.0 * CAST(paid_amount AS REAL) / CAST(billed_amount AS REAL), 2) AS payment_rate_pct,

    -- Date columns broken down for charts in Power BI
    -- month_label gives us "2024-01" format for monthly trend charts
    strftime('%Y-%m', date_of_service) AS month_label,
    CAST(strftime('%Y', date_of_service) AS INTEGER) AS claim_year,
    CAST(strftime('%m', date_of_service) AS INTEGER) AS claim_month,

    -- Which quarter the claim belongs to (Q1, Q2, Q3, Q4)
    CASE
        WHEN CAST(strftime('%m', date_of_service) AS INTEGER) <= 3 THEN 'Q1'
        WHEN CAST(strftime('%m', date_of_service) AS INTEGER) <= 6 THEN 'Q2'
        WHEN CAST(strftime('%m', date_of_service) AS INTEGER) <= 9 THEN 'Q3'
        ELSE 'Q4'
    END AS claim_quarter,

    -- Flag: is this claim denied? (1 = yes, 0 = no)
    -- Used to count rejections easily in analysis
    CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END AS is_rejected,

    -- Flag: is this claim paid/approved? (1 = yes, 0 = no)
    CASE WHEN claim_status = 'Paid'   THEN 1 ELSE 0 END AS is_approved,

    -- Flag: does this claim need follow-up? (1 = yes, 0 = no)
    CASE WHEN follow_up_required = 'Yes' THEN 1 ELSE 0 END AS follow_up_flag,

    -- Was the rejection caused by something preventable?
    -- Preventable = admin/process errors that staff can fix
    -- Non-Preventable = clinical reasons outside operations control
    -- N/A = claim was not denied so this does not apply
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

    -- Claim size category based on billed amount
    -- Used to see if larger claims get rejected more often
    CASE
        WHEN CAST(billed_amount AS REAL) < 500    THEN 'Low (under $500)'
        WHEN CAST(billed_amount AS REAL) <= 2000  THEN 'Medium ($500-$2K)'
        WHEN CAST(billed_amount AS REAL) <= 10000 THEN 'High ($2K-$10K)'
        ELSE 'Very High (over $10K)'
    END AS claim_size_bucket

FROM claims_clean;


-- STEP 6: Verify the final table
-- Quick check to confirm row count and flag totals look right
-- Expected: 1000 total, 328 denied, 334 paid
-- ============================================================
SELECT
    COUNT(*)         AS total_rows,
    SUM(is_rejected) AS total_denied,
    SUM(is_approved) AS total_paid
FROM claims_final;