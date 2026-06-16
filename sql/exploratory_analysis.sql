-- ============================================================
-- FILE: exploratory_analysis.sql
-- PROJECT: Healthcare Claims Analytics Dashboard
-- PURPOSE: Identify denial patterns, financial impact, and
--          operational bottlenecks across 1,000 claims
-- ============================================================


-- QUERY 1: Claim status distribution
-- ============================================================
SELECT
    claim_status,
    COUNT(*) AS total_claims
FROM claims_final
GROUP BY claim_status
ORDER BY total_claims DESC;


-- QUERY 2: Top denial reasons ranked by volume
-- Ordered by frequency to prioritize process improvement efforts
-- ============================================================
SELECT
    reason_code,
    COUNT(*) AS total
FROM claims_final
WHERE claim_status = 'Denied'
GROUP BY reason_code
ORDER BY total DESC;


-- QUERY 3: Denial rate by payer
-- Distinguishes between raw denial count and denial rate
-- to avoid conflating volume with performance
-- ============================================================
SELECT
    insurance_type,
    COUNT(*) AS total_claims,
    SUM(is_rejected) AS total_denied,
    ROUND(100.0 * SUM(is_rejected) / COUNT(*), 2) AS denial_rate_pct
FROM claims_final
GROUP BY insurance_type
ORDER BY denial_rate_pct DESC;


-- QUERY 4: Preventable vs non-preventable denial split
-- Window function used to calculate percentage within denied claims only
-- ============================================================
SELECT
    preventable_flag,
    COUNT(*) AS total,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM claims_final
WHERE claim_status = 'Denied'
GROUP BY preventable_flag
ORDER BY total DESC;


-- QUERY 5: Monthly denial trend
-- ============================================================
SELECT
    month_label,
    COUNT(*) AS total_claims,
    SUM(is_rejected) AS total_denied,
    ROUND(100.0 * SUM(is_rejected) / COUNT(*), 2) AS denial_rate_pct
FROM claims_final
GROUP BY month_label
ORDER BY month_label;


-- QUERY 6: Financial summary
-- ============================================================
SELECT
    ROUND(SUM(billed_amount), 2)  AS total_billed,
    ROUND(SUM(allowed_amount), 2) AS total_allowed,
    ROUND(SUM(paid_amount), 2)    AS total_paid,
    ROUND(SUM(denied_amount), 2)  AS total_denied
FROM claims_final;
