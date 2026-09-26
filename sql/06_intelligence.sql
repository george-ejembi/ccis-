-- =========================================================
--  INTELLIGENCE
--  Money exposure and retention actions.
-- =========================================================

CREATE TABLE intelligence.revenue_at_risk (
    risk_id                        BIGSERIAL PRIMARY KEY,
    customer_id                    UUID NOT NULL,
    predicted_churn_probability    NUMERIC(5,2),
    estimated_monthly_revenue_loss NUMERIC(12,2),
    risk_generated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_prob_range
        CHECK (predicted_churn_probability IS NULL
               OR predicted_churn_probability BETWEEN 0 AND 1)
);

CREATE TABLE intelligence.retention_interventions (
    intervention_id      BIGSERIAL PRIMARY KEY,
    customer_id          UUID NOT NULL,
    intervention_type    VARCHAR(255),
    intervention_priority VARCHAR(50),
    intervention_status  VARCHAR(50) DEFAULT 'PENDING',
    generated_reason     TEXT,
    created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_priority
        CHECK (intervention_priority IN ('CRITICAL', 'HIGH', 'NORMAL')),
    CONSTRAINT chk_status
        CHECK (intervention_status IN ('PENDING','OPEN','IN_PROGRESS','CLOSED','DISMISSED'))
);