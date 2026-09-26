# Customer Churn Intelligence System (CCIS)

A production-grade PostgreSQL decision-intelligence platform that identifies
at-risk customers, quantifies revenue exposure, and automatically generates
retention interventions — end-to-end, on a schedule, with full audit trail.

## The Business Problem

For subscription businesses, losing a customer is 5–25× more expensive than
retaining one. But most companies only discover churn *after* it happens —
when the customer has already stopped logging in, stopped paying, and stopped
answering emails.

CCIS flips the timeline. It continuously scores every customer for churn
risk, quantifies how much revenue each one represents, and generates the
right retention action — *before* the customer is gone.

## Current Results (sample dataset, 500 customers)

| Metric | Value |
|---|---|
| Customers scored | 500 |
| HIGH RISK customers | 103 (20.6%) |
| MEDIUM RISK customers | 51 (10.2%) |
| Annual revenue exposure | **$180,207.72** |
| Interventions auto-generated | 63 (batch) + 337 (event-driven) |
| Pipeline runtime | < 2 seconds end-to-end |

## Architecture

```
┌───────────────┐    ┌───────────────┐    ┌────────────────┐    ┌────────────────┐
│   STAGING     │───▶│   WAREHOUSE   │───▶│ FEATURE STORE  │───▶│ INTELLIGENCE   │
│  raw_*        │    │  dim_*        │    │  churn_        │    │  revenue_at_   │
│  (as-received)│    │  fact_*       │    │  features      │    │  risk          │
│               │    │  (partitioned)│    │                │    │  interventions │
└───────────────┘    └───────┬───────┘    └────────────────┘    └───────┬────────┘
                             │                                          │
                    ┌────────┴────────┐                       ┌─────────┴────────┐
                    │  MATERIALIZED   │                       │    TRIGGERS      │
                    │  VIEW           │                       │  audit + support │
                    │  mv_customer_   │                       │  escalation      │
                    │  risk_summary   │                       │                  │
                    └─────────────────┘                       └──────────────────┘
                                                                      │
                                                             ┌────────┴────────┐
                                                             │  EXECUTIVE      │
                                                             │  DASHBOARD      │
                                                             │  (Power BI)     │
                                                             └─────────────────┘
```

Full diagram and design rationale: [`docs/architecture.md`](docs/architecture.md).

## Technology

- **PostgreSQL 16** — partitioning, materialized views, PL/pgSQL procedures, triggers, CHECK constraints, RBAC
- **Power BI** — executive dashboards (connection via `bi_readonly` role)
- **pg_cron** — nightly pipeline automation

## Repository Structure

```
ccis/
├── sql/
│   ├── 00_extensions.sql          -- pgcrypto for UUID generation
│   ├── 01_database.sql            -- CREATE DATABASE
│   ├── 02_schemas_roles.sql       -- 7 schemas + 3 roles + RBAC grants
│   ├── 03_staging.sql             -- raw landing zone
│   ├── 04_warehouse.sql           -- dim + facts + 48 monthly partitions
│   ├── 05_feature_store.sql       -- ML-ready customer features
│   ├── 06_intelligence.sql        -- revenue-at-risk + interventions
│   ├── 07_audit_monitoring.sql    -- audit log + pipeline telemetry
│   ├── 08_indexes.sql             -- 10 strategic indexes
│   ├── 09_procedures.sql          -- matview + 4 core procedures
│   ├── 10_views.sql               -- executive dashboard view
│   ├── 11_triggers.sql            -- audit + escalation triggers
│   ├── 12_seed_data.sql           -- 500-customer sample dataset
│   ├── 12b_seed_unhealthy.sql     -- inject realistic at-risk cohort
│   └── 13_run_pipeline.sql        -- the end-to-end pipeline
└── docs/
    ├── architecture.md
    ├── data_dictionary.md
    └── churn_methodology.md
```

## How to Run

### Prerequisites
- PostgreSQL 16+
- `psql` on your PATH

### Setup (one time)

```bash
# 1. Create database (run alone — cannot be inside a transaction)
psql -U postgres -f sql/01_database.sql

# 2. Everything else, in order
psql -U postgres -d ccis_platform -f sql/00_extensions.sql
psql -U postgres -d ccis_platform -f sql/02_schemas_roles.sql
psql -U postgres -d ccis_platform -f sql/03_staging.sql
psql -U postgres -d ccis_platform -f sql/04_warehouse.sql
psql -U postgres -d ccis_platform -f sql/05_feature_store.sql
psql -U postgres -d ccis_platform -f sql/06_intelligence.sql
psql -U postgres -d ccis_platform -f sql/07_audit_monitoring.sql
psql -U postgres -d ccis_platform -f sql/08_indexes.sql
psql -U postgres -d ccis_platform -f sql/09_procedures.sql
psql -U postgres -d ccis_platform -f sql/10_views.sql
psql -U postgres -d ccis_platform -f sql/11_triggers.sql
```

### Load sample data

```bash
psql -U postgres -d ccis_platform -f sql/12_seed_data.sql
psql -U postgres -d ccis_platform -f sql/12b_seed_unhealthy.sql
```

### Run the pipeline

```bash
psql -U postgres -d ccis_platform -f sql/13_run_pipeline.sql
```

### Verify

```sql
SELECT * FROM marts.vw_executive_churn_dashboard;
```

## How the Churn Score Works

```
churn_risk_score = LEAST(100,
      inactivity_days      × 0.35
    + failed_payments      × 15
    + support_ticket_count × 10
)

Risk bands:
    ≥ 80  →  HIGH RISK
    ≥ 50  →  MEDIUM RISK
    else  →  LOW RISK
```

Full methodology and weight justification:
[`docs/churn_methodology.md`](docs/churn_methodology.md).

## Design Decisions Worth Noting

1. **Partitioned fact table** — `fact_transactions` is range-partitioned by month.
   A query for "Q1 2026" scans 3 partitions, not the whole table.
2. **Separate aggregation CTEs in the materialized view** — prevents the classic
   SQL bug where joining 3 fact tables in one query multiplies rows and corrupts
   `AVG()` and `SUM()`.
3. **CHECK constraints as a second line of defense** — even if a procedure has a bug,
   `churn_risk_score` cannot exceed 100 and `predicted_churn_probability` cannot
   exceed 1.0. The database itself refuses bad data.
4. **Idempotent pipeline** — every procedure `TRUNCATE`s before inserting, so
   re-running is always safe. Verified by running the pipeline twice and confirming
   identical output.
5. **Event-driven + batch** — most of the retention interventions are generated
   in batch, but HIGH-priority support tickets trigger an immediate CRITICAL
   intervention via a database trigger. Both paths write to the same table.
6. **Audit trail on customer changes** — every INSERT/UPDATE/DELETE on
   `dim_customers` writes to `audit.audit_log` with the acting user and timestamp.

## Roadmap

- [ ] Power BI executive dashboard (screenshots in `docs/`)
- [ ] `pg_cron` nightly scheduling
- [ ] Real ML model (currently a rules-based weighted score)
- [ ] Customer-level intervention outcome tracking (A/B test retention offers)

## Author

[George Ejembi] — [ejembigeorge3@gmail.com]
