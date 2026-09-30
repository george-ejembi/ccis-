# CCIS — Next Steps

Roadmap for the project. Update as items are completed.

**Created:** 2026-10-01
**Current status:** Core platform complete. Documentation in progress.
**Next milestone:** Power BI dashboard + GitHub push.

## Completed

- [x] Database, schemas, roles created
- [x] Staging tables (4)
- [x] Warehouse dimension + 3 fact tables + 48 partitions
- [x] Feature store with CHECK-constrained scores
- [x] Intelligence tables with intervention workflow
- [x] Audit log auto-populated by trigger
- [x] 10 strategic indexes
- [x] 5 procedures + 1 materialized view + 1 view
- [x] 2 triggers (audit + support escalation)
- [x] Seed data: 500 customers + realistic at-risk cohort
- [x] End-to-end pipeline verified
- [x] Idempotency verified (double-run produces identical output)
- [x] 10 data quality assertions in tests/quality_checks.sql
- [x] BI read-only role for Power BI connection
- [x] Power BI dashboard
- [x] Screenshots exported to docs/screenshots/
- [x] README finalized with screenshots and results
- [x] GitHub push

## Next Up (After Portfolio Polish)

### Near-term

- [ ] `pg_cron` nightly scheduling
- [ ] Monitoring dashboard (query on monitoring.query_performance_logs)
- [ ] Automated quality checks run as part of the pipeline wrapper

### Medium-term

- [ ] Time-weighted churn signals (recent events count more)
- [ ] Replace rules-based score with logistic regression
- [ ] Track intervention outcomes (A/B test retention offers)
- [ ] Add `staging -> warehouse` transformation procedure
      (currently seed data goes straight to warehouse)

### Long-term

- [ ] Real data ingestion pipeline (Airflow or similar)
- [ ] Customer-facing churn score API
- [ ] Multi-tenant support
- [ ] Backup and disaster recovery plan

## Do NOT Do (Yet)

- pg_cron / scheduling: save for a Data Engineer interview where you can
  discuss operational ownership
- ML model: the rules-based score is more defensible in an interview
  because every decision is explainable

## The One-Sentence Pitch

"I built a PostgreSQL decision-intelligence platform that identifies
$180K of annual revenue exposure across 500 customers and auto-generates
retention interventions, end-to-end, in under 2 seconds."

## How to Resume After a Break

1. Open the project folder in VS Code
2. Read this file
3. Check which items are still open
4. Resume from the first unchecked item
5. The pipeline and tests still work as long as the database is running

## Key Files to Remember

| File | Purpose |
|---|---|
| sql/13_run_pipeline.sql | Run the full pipeline |
| tests/quality_checks.sql | Verify data quality |
| docs/architecture.md | Full system design |
| docs/churn_methodology.md | Explains the scoring |
| README.md | Public-facing project page |
