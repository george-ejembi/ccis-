# Data Dictionary

Every table, every column, and what it means.

## `staging` — Raw landing zone

### `staging.raw_customers`

| Column | Type | Notes |
|---|---|---|
| customer_id | UUID | Primary key |
| full_name | VARCHAR(255) | |
| gender | VARCHAR(50) | |
| age | INT | |
| country | VARCHAR(100) | |
| city | VARCHAR(100) | |
| signup_date | DATE | |
| acquisition_channel | VARCHAR(100) | Facebook Ads / Google Ads / Referral / Organic |
| created_at | TIMESTAMP | Defaults to now |

### `staging.raw_transactions`

| Column | Type | Notes |
|---|---|---|
| transaction_id | UUID | Primary key |
| customer_id | UUID | Business key (FK unenforced at staging) |
| transaction_date | DATE | |
| amount | NUMERIC(12,2) | |
| payment_status | VARCHAR(50) | SUCCESS / FAILED |
| subscription_type | VARCHAR(100) | Basic / Premium / Enterprise |
| created_at | TIMESTAMP | |

### `staging.raw_customer_activity`

| Column | Type | Notes |
|---|---|---|
| activity_id | UUID | Primary key |
| customer_id | UUID | |
| activity_date | DATE | |
| session_duration_minutes | INT | |
| login_count | INT | |
| feature_used | VARCHAR(255) | Dashboard / Reports / Billing / Settings |
| created_at | TIMESTAMP | |

### `staging.raw_support_tickets`

| Column | Type | Notes |
|---|---|---|
| ticket_id | UUID | Primary key |
| customer_id | UUID | |
| ticket_date | DATE | |
| issue_category | VARCHAR(255) | Billing / Technical / Account / Other |
| priority_level | VARCHAR(50) | LOW / MEDIUM / HIGH |
| resolution_status | VARCHAR(50) | |
| resolution_hours | INT | |
| created_at | TIMESTAMP | |

## `warehouse` — Cleaned and conformed

### `warehouse.dim_customers`

| Column | Type | Notes |
|---|---|---|
| customer_sk | SERIAL | Primary key (surrogate) |
| customer_id | UUID | Business key, UNIQUE |
| full_name | VARCHAR(255) | |
| gender | VARCHAR(50) | |
| age | INT | CHECK age >= 18 |
| country | VARCHAR(100) | |
| city | VARCHAR(100) | |
| signup_date | DATE | |
| acquisition_channel | VARCHAR(100) | |
| customer_status | VARCHAR(50) | Default 'ACTIVE' |
| created_at | TIMESTAMP | |

### `warehouse.fact_transactions`

Partitioned by `transaction_date` (range). 48 monthly partitions spanning 2024-01 through 2027-12.

| Column | Type | Notes |
|---|---|---|
| transaction_sk | BIGSERIAL | Part of composite primary key |
| transaction_id | UUID | Source system ID |
| customer_id | UUID | FK to dim_customers.customer_id |
| transaction_date | DATE | Part of composite PK, partition key |
| amount | NUMERIC(12,2) | CHECK amount >= 0 |
| payment_status | VARCHAR(50) | |
| subscription_type | VARCHAR(100) | |
| created_at | TIMESTAMP | |

### `warehouse.fact_customer_activity`

| Column | Type | Notes |
|---|---|---|
| activity_sk | BIGSERIAL | Primary key |
| activity_id | UUID | UNIQUE |
| customer_id | UUID | |
| activity_date | DATE | |
| session_duration_minutes | INT | |
| login_count | INT | |
| feature_used | VARCHAR(255) | |
| created_at | TIMESTAMP | |

### `warehouse.fact_support_interactions`

| Column | Type | Notes |
|---|---|---|
| support_sk | BIGSERIAL | Primary key |
| ticket_id | UUID | UNIQUE |
| customer_id | UUID | |
| ticket_date | DATE | |
| issue_category | VARCHAR(255) | |
| priority_level | VARCHAR(50) | |
| resolution_status | VARCHAR(50) | |
| resolution_hours | INT | |
| created_at | TIMESTAMP | |

## `feature_store` — ML-ready features

### `feature_store.customer_churn_features`

One row per customer. Rebuilt on every pipeline run.

| Column | Type | Meaning |
|---|---|---|
| feature_id | BIGSERIAL | Primary key |
| customer_id | UUID | Business key |
| inactivity_days | INT | Days since last activity (999 if never active) |
| avg_monthly_spend | NUMERIC(12,2) | Mean transaction amount |
| failed_payments | INT | Count of FAILED transactions |
| support_ticket_count | INT | Total tickets opened |
| avg_session_duration | NUMERIC(10,2) | Mean minutes per session |
| churn_risk_score | NUMERIC(5,2) | 0-100, CHECK enforced |
| risk_level | VARCHAR(50) | HIGH RISK / MEDIUM RISK / LOW RISK |
| feature_generated_at | TIMESTAMP | Pipeline run time |

## `intelligence` — Decisions

### `intelligence.revenue_at_risk`

| Column | Type | Meaning |
|---|---|---|
| risk_id | BIGSERIAL | Primary key |
| customer_id | UUID | |
| predicted_churn_probability | NUMERIC(5,2) | 0.00-1.00, CHECK enforced |
| estimated_monthly_revenue_loss | NUMERIC(12,2) | avg_monthly_spend * probability |
| risk_generated_at | TIMESTAMP | |

### `intelligence.retention_interventions`

| Column | Type | Meaning |
|---|---|---|
| intervention_id | BIGSERIAL | Primary key |
| customer_id | UUID | |
| intervention_type | VARCHAR(255) | PAYMENT RETRY CAMPAIGN / CUSTOMER RE-ENGAGEMENT / PRIORITY SUPPORT ESCALATION / LOYALTY RETENTION OFFER / SUPPORT ESCALATION |
| intervention_priority | VARCHAR(50) | CRITICAL / HIGH / NORMAL, CHECK enforced |
| intervention_status | VARCHAR(50) | PENDING / OPEN / IN_PROGRESS / CLOSED / DISMISSED, CHECK enforced |
| generated_reason | TEXT | Human-readable explanation |
| created_at | TIMESTAMP | |

## `marts` — Analytics outputs

### `marts.mv_customer_risk_summary` (materialized view)

One row per customer, pre-aggregated features. Rebuilt by
`marts.sp_refresh_customer_risk_summary()`. Unique index on `customer_id`
enables `REFRESH CONCURRENTLY`.

| Column | Type |
|---|---|
| customer_id | UUID |
| inactivity_days | INT |
| support_ticket_count | BIGINT |
| failed_payments | BIGINT |
| avg_monthly_spend | NUMERIC(12,2) |
| avg_session_duration | NUMERIC(10,2) |

### `marts.vw_executive_churn_dashboard` (view)

| Column | Type | Meaning |
|---|---|---|
| risk_level | VARCHAR(50) | |
| customer_count | BIGINT | |
| avg_risk_score | NUMERIC | |
| monthly_revenue_exposure | NUMERIC | |
| annual_revenue_exposure | NUMERIC | |

## `audit` and `monitoring`

### `audit.audit_log`

| Column | Type | Meaning |
|---|---|---|
| audit_id | BIGSERIAL | Primary key |
| table_name | VARCHAR(255) | Table that changed |
| operation_type | VARCHAR(50) | INSERT / UPDATE / DELETE |
| changed_by | VARCHAR(255) | PostgreSQL role that made the change |
| changed_at | TIMESTAMP | |
| record_reference | TEXT | The customer_id that changed |

### `monitoring.query_performance_logs`

| Column | Type | Meaning |
|---|---|---|
| log_id | BIGSERIAL | Primary key |
| query_name | VARCHAR(255) | Pipeline stage name |
| execution_time_ms | NUMERIC(12,2) | Duration in milliseconds |
| logged_at | TIMESTAMP | |