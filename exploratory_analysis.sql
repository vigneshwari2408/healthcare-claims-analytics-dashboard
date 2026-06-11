-- ============================================================
-- FILE: exploratory_analysis.sql
-- PROJECT: Healthcare Claims Analytics Dashboard
-- PURPOSE: Explore the cleaned data to find patterns and insights
--          that will appear in the dashboard and README
-- HOW TO USE: Run each query one at a time by highlighting it
--             and pressing F5
-- ============================================================


-- QUERY 1: How many claims are Paid, Denied, and Under Review?
-- This gives us the big picture breakdown of claim outcomes
-- ============================================================
SELECT
    claim_status,
    COUNT(*) AS total_claims
FROM claims_final
GROUP BY claim_status
ORDER BY total_claims DESC;


-- QUERY 2: What are the most common reasons for denial?
-- We filter to only Denied claims and count each reason
-- The top reason tells us where to focus process improvements
-- ============================================================
SELECT
    reason_code,
    COUNT(*) AS total
FROM claims_final
WHERE claim_status = 'Denied'
GROUP BY reason_code
ORDER BY total DESC;


-- QUERY 3: Which insurance type has the highest denial rate?
-- denial_rate_pct = (denied claims / total claims) x 100
-- Helps identify which payers are causing the most problems
-- ============================================================
SELECT
    insurance_type,
    COUNT(*) AS total_claims,
    SUM(is_rejected) AS total_denied,
    ROUND(100.0 * SUM(is_rejected) / COUNT(*), 2) AS denial_rate_pct
FROM claims_final
GROUP BY insurance_type
ORDER BY denial_rate_pct DESC;


-- QUERY 4: How many denials were preventable vs non-preventable?
-- Preventable = caused by admin errors staff can fix
-- Non-Preventable = clinical reasons outside operations control
-- This is the most important finding for recommendations
-- ============================================================
SELECT
    preventable_flag,
    COUNT(*) AS total,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM claims_final
WHERE claim_status = 'Denied'
GROUP BY preventable_flag
ORDER BY total DESC;


-- QUERY 5: How does the denial rate change month by month?
-- Shows whether denials are improving or getting worse over time
-- ============================================================
SELECT
    month_label,
    COUNT(*) AS total_claims,
    SUM(is_rejected) AS total_denied,
    ROUND(100.0 * SUM(is_rejected) / COUNT(*), 2) AS denial_rate_pct
FROM claims_final
GROUP BY month_label
ORDER BY month_label;


-- QUERY 6: What is the financial summary?
-- total_billed  = what providers charged
-- total_allowed = what insurers agreed to pay
-- total_paid    = what was actually paid
-- total_denied  = money lost to denials
-- ============================================================
SELECT
    ROUND(SUM(billed_amount), 2)  AS total_billed,
    ROUND(SUM(allowed_amount), 2) AS total_allowed,
    ROUND(SUM(paid_amount), 2)    AS total_paid,
    ROUND(SUM(denied_amount), 2)  AS total_denied
FROM claims_final;