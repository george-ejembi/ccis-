-- =========================================================
--  FEATURE STORE
--  One row per customer. This is what the churn model "sees".
-- =========================================================

CREATE TABLE feature_store.customer_churn_features (
    feature_id           BIGSERIAL PRIMARY KEY,
    customer_id          UUID NOT NULL,
    inactivity_days      INT,
    avg_monthly_spend    NUMERIC(12,2),
    failed_payments      INT,
    support_ticket_count INT,
    avg_session_duration NUMERIC(10,2),
    churn_risk_score     NUMERIC(5,2),
    risk_level           VARCHAR(50),
    feature_generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_score_range
        CHECK (churn_risk_score IS NULL OR churn_risk_score BETWEEN 0 AND 100)
);