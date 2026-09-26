# CCIS Architecture

## Layer-by-Layer

### 1. Staging (`staging` schema)
- **Tables**: `raw_customers`, `raw_transactions`, `raw_customer_activity`, `raw_support_tickets`
- **Purpose**: Land raw data exactly as received from source systems.
- **Design principle**: No constraints beyond primary keys. Staging accepts whatever
  arrives so that bad rows can be *inspected* before being rejected. This is the
  "L" in ELT.

### 2. Warehouse (`warehouse` schema)
- **Dimension**: `dim_customers` — one row per customer, surrogate key `customer_sk`
- **Facts**:
  - `fact_transactions` — range-partitioned by month, 48 partitions spanning 2024–2027
  - `fact_customer_activity` — one row per session
  - `fact_support_interactions` — one row per ticket
- **Purpose**: Cleaned, conformed, and query-optimized. This is where `CHECK`
  constraints live (`age >= 18`, `amount >= 0`).

### 3. Feature Store (`feature_store` schema)
- **Table**: `customer_churn_features` — one row per customer, ML-ready
- **Purpose**: Decouples model inputs from model logic. If the churn formula
  changes, only the procedure changes — the table stays stable.

### 4. Intelligence (`intelligence` schema)
- **Tables**:
  - `revenue_at_risk` — churn probability × monthly spend per customer
  - `retention_interventions` — auto-generated actions with priority + status
- **Purpose**: Turns scores into decisions. This is the "so what?" layer.

### 5. Marts (`marts` schema)
- **Materialized View**: `mv_customer_risk_summary` — pre-aggregated features
- **View**: `vw_executive_churn_dashboard` — grouped risk distribution

### 6. Audit & Monitoring (`audit`, `monitoring` schemas)
- `audit.audit_log` — auto-populated by trigger on `dim_customers`
- `monitoring.query_performance_logs` — pipeline run telemetry

## Pipeline Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     NIGHTLY PIPELINE                        │
│                                                             │
│  1. CALL marts.sp_refresh_customer_risk_summary()           │
│        ↓ rebuilds mv_customer_risk_summary (aggregates)     │
│                                                             │
│  2. CALL intelligence.sp_calculate_churn_risk()             │
│        ↓ TRUNCATE + re-score every customer                 │
│                                                             │
│  3. CALL intelligence.sp_generate_revenue_at_risk()         │
│        ↓ TRUNCATE + write revenue exposure                   │
│                                                             │
│  4. CALL intelligence.sp_generate_interventions()           │
│        ↓ generate PENDING actions for MEDIUM/HIGH risk      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │  Power BI          │
                    │  Executive Dashboard│
                    └────────────────────┘
```

## Event-Driven Side Channel

In parallel with the nightly batch, a **trigger** watches for HIGH-priority
support tickets:

```
INSERT into fact_support_interactions (priority_level = 'HIGH')
        ↓
trg_support_escalation fires
        ↓
INSERT into retention_interventions
    (type = 'SUPPORT ESCALATION', priority = 'CRITICAL', status = 'OPEN')
```

This means the intervention queue is updated in **real time** for the most
urgent cases, while the bulk of scoring runs nightly. Both paths write to the
same `retention_interventions` table.

## Why These Choices

| Choice | Reason |
|---|---|
| UUIDs for business keys | Globally unique, safe for multi-source ingestion |
| SERIAL/BIGSERIAL for surrogate keys | 4–8 bytes vs 16, faster joins |
| Monthly partitioning | Query pruning; a Q1 query scans 3 partitions, not 48 |
| Materialized view for features | Complex aggregation computed once per run, not per query |
| TRUNCATE-then-INSERT in procedures | Makes the pipeline idempotent and re-runnable |
| CHECK constraints on scores | Belt-and-braces defense against procedure bugs |
| Triggers for audit + escalation | Guarantees events fire regardless of which client writes |
