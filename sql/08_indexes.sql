-- =========================================================
--  INDEXING STRATEGY
--  Only index columns that appear in WHERE/JOIN/ORDER BY.
-- =========================================================

CREATE INDEX idx_transactions_customer
    ON warehouse.fact_transactions(customer_id);

-- Note: PostgreSQL automatically creates indexes on the
-- partition key (transaction_date), so we don't re-index it.

CREATE INDEX idx_activity_customer
    ON warehouse.fact_customer_activity(customer_id);

CREATE INDEX idx_activity_date
    ON warehouse.fact_customer_activity(activity_date);

CREATE INDEX idx_support_customer
    ON warehouse.fact_support_interactions(customer_id);

CREATE INDEX idx_support_priority
    ON warehouse.fact_support_interactions(priority_level);

CREATE INDEX idx_customer_status
    ON warehouse.dim_customers(customer_status);

CREATE INDEX idx_features_customer
    ON feature_store.customer_churn_features(customer_id);

CREATE INDEX idx_features_risk_level
    ON feature_store.customer_churn_features(risk_level);

CREATE INDEX idx_interventions_customer
    ON intelligence.retention_interventions(customer_id);

CREATE INDEX idx_interventions_status
    ON intelligence.retention_interventions(intervention_status);