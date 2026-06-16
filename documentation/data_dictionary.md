# Data Dictionary

## Original Columns (from raw dataset)

| Column | Description | Example |
|--------|-------------|---------|
| claim_id | Unique identifier for each claim | 0HO1FSN4AP |
| provider_id | Unique identifier for the healthcare provider | 126528997 |
| patient_id | Unique identifier for the patient | 7936697103 |
| date_of_service | Original date of service as provided in raw data | 8/7/2024 |
| insurance_type | Type of insurance — Commercial, Medicare, Medicaid, Self-Pay | Medicare |
| claim_status | Current claim outcome — Paid, Denied, Under Review | Denied |
| reason_code | Reason for denial if applicable | Authorization not obtained |
| follow_up_required | Whether follow-up action is needed — Yes or No | Yes |
| ar_status | Accounts receivable status — Closed, Open, Pending, On Hold, Partially Paid, Denied | Pending |
| outcome | Final outcome of the claim | Denied |
| procedure_code | Medical procedure identifier | 99231 |
| diagnosis_code | Diagnosis code for the medical condition | A02.1 |
| billed_amount | Total amount billed by the provider (USD) | 304 |
| allowed_amount | Amount approved by the insurer (USD) | 218 |
| paid_amount | Amount actually paid by the insurer (USD) | 203 |

## Engineered Columns (created during SQL cleaning)

| Column | Description | Example |
|--------|-------------|---------|
| service_date | Date of service converted to YYYY-MM-DD format for SQL date functions | 2024-08-07 |
| denied_amount | Amount not paid — calculated as billed_amount minus paid_amount | 101 |
| payment_rate_pct | Percentage of billed amount that was paid — (paid / billed) x 100 | 66.78 |
| month_label | Year and month label for monthly trend charts | 2024-08 |
| claim_month | Numeric month extracted from service_date | 8 |
| claim_year | Numeric year extracted from service_date | 2024 |
| claim_quarter | Quarter the claim belongs to — Q1, Q2, Q3, Q4 | Q3 |
| is_rejected | Binary flag — 1 if claim_status is Denied, 0 otherwise | 1 |
| is_approved | Binary flag — 1 if claim_status is Paid, 0 otherwise | 0 |
| follow_up_flag | Binary flag — 1 if follow_up_required is Yes, 0 otherwise | 1 |
| preventable_flag | Classifies denied claims as Preventable, Non-Preventable, or N/A based on reason_code | Preventable |
| claim_size_bucket | Groups claims by billed amount — Low under $500, Medium $500-$2K, High $2K-$10K, Very High over $10K | Low (under $500) |

## Preventable Flag Classification

| Reason Code | Classification |
|-------------|---------------|
| Authorization not obtained | Preventable |
| Duplicate claim | Preventable |
| Incorrect billing information | Preventable |
| Missing documentation | Preventable |
| Patient eligibility issues | Preventable |
| Lack of medical necessity | Non-Preventable |
| Pre-existing condition | Non-Preventable |
| Service not covered | Non-Preventable |
