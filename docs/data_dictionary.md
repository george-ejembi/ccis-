# Data Dictionary

## `staging` — Raw landing zone

| Table | Column | Type | Notes |
|---|---|---|---|
| raw_customers | customer_id | UUID | PK |
| | full_name, gender, age, country, city | | as received |
| | signup_date | DATE | |
| | acquisition_channel | VARCHAR(100) | Facebook Ads / Google Ads / Referral / Organic |
| raw_transactions | transaction_id | UUID | PK |
| | customer_id | UUID | FK (unenforced at staging) |
| | transaction_date | DATE | |
| | amount | NUMERIC(12,2) | |
| | payment_status | VARCHAR(50) | SUCCESS / FAILED |
| | subscription_type | VARCHAR(100) | Basic / Premium / Enterprise |
| raw_customer_activity | activity_id | UUID | PK |
| | activity_date | DATE | |
| | session_duration_minutes | INT | |
| | login_count | INT | |
| | feature_used | VARCHAR(255) | |
| raw_support_tickets | ticket_id | UUID | PK |
| | ticket_date | DATE | |
| | issue_category | VARCHAR(255) | Billing / Technical / Account / Other |
| | priority_level | VARCHAR(50) | LOW / MEDIUM / HIGH |
| | resolution_status | VARCHAR(50) | |
| | resolution_hours | INT | |

## `warehouse` — Cleaned & conformed

| Table | Column | Type | Notes |
|---|---|---|---|
| dim_customers | customer_sk | SERIAL | PK — surrogate |
| | customer_id | UUID | business key, unique |
| | customer_status | VARCHAR(50) | default ACTIVE |
| | CONSTRAINT chk_age | | age >= 18 |
| fact_transactions | transaction_sk | BIGSERIAL | PK part 1 |
| | transaction_date | DATE | PK part 2 — partition key |
| | amount | NUMERIC(12,2) | CONSTRAINT chk_amount: >= 0 |
| fact_customer_activity | activity_sk | BIGSERIAL | PK |
| fact_support_interactions | support_sk | BIGSERIAL | PK |

**Partitions**: `fact_transactions_YYYY_MM` for 2024-01 through 2027-12 (48 total).

## `feature_store`

| Column | Type | Meaning |
|---|---|---|
| customer_id | UUID | business key |
| inactivity_days | INT | days since last activity (999 if never active) |
| avg_monthly_spend | NUMERIC(12,2) | mean transaction amount |
| failed_payments | INT | count of FAILED transactions |
| support_ticket_count | INT | total tickets opened |
| avg_session_duration | NUMERIC(10,2) | mean minutes per session |
| churn_risk_score | NUMERIC(5,2) | 0–100 (CHECK enforced) |
| risk_level | VARCHAR(50) | HIGH RISK / MEDIUM RISK / LOW RISK |
| feature_generated_at | TIMESTAMP | pipeline run time |

## `intelligence`

| Column | Type | Meaning |
|---|---|---|
| predicted_churn_probability | NUMERIC(5,2) | 0.00–1.00 (CHECK enforced) |
| estimated_monthly_revenue_loss | NUMERIC(12,2) | avg_monthly_spend × probability |
| intervention_type | VARCHAR(255) | e.g. PAYMENT RETRY CAMPAIGN |
| intervention_priority | VARCHAR(50) | CRITICAL / HIGH / NORMAL |
| intervention_status | VARCHAR(50) | PENDING / OPEN / IN_PROGRESS / CLOSED / DISMISSED |

## `audit`, `monitoring`

| Table | Purpose |
|---|---|
| audit.audit_log | one row per change on `dim_customers` |
| monitoring.query_performance_logs | pipeline run telemetry |