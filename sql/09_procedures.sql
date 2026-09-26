-- =========================================================
--  1. MATERIALIZED VIEW — the source of truth for features
--  Aggregates each fact table SEPARATELY, then joins.
--  This prevents the "joined rows get duplicated" bug.
-- =========================================================

DROP MATERIALIZED VIEW IF EXISTS marts.mv_customer_risk_summary CASCADE;

CREATE MATERIALIZED VIEW marts.mv_customer_risk_summary AS
WITH activity AS (
    SELECT
        customer_id,
        MAX(activity_date)                            AS last_activity_date,
        AVG(session_duration_minutes)::NUMERIC(10,2)  AS avg_session_duration
    FROM warehouse.fact_customer_activity
    GROUP BY customer_id
),
support AS (
    SELECT customer_id, COUNT(*) AS support_ticket_count
    FROM warehouse.fact_support_interactions
    GROUP BY customer_id
),
txn AS (
    SELECT
        customer_id,
        COUNT(*) FILTER (WHERE payment_status = 'FAILED') AS failed_payments,
        AVG(amount)::NUMERIC(12,2)                        AS avg_monthly_spend
    FROM warehouse.fact_transactions
    GROUP BY customer_id
)
SELECT
    d.customer_id,
    COALESCE(CURRENT_DATE - a.last_activity_date, 999)  AS inactivity_days,
    COALESCE(s.support_ticket_count, 0)                 AS support_ticket_count,
    COALESCE(t.failed_payments, 0)                      AS failed_payments,
    COALESCE(t.avg_monthly_spend, 0)                    AS avg_monthly_spend,
    COALESCE(a.avg_session_duration, 0)                 AS avg_session_duration
FROM warehouse.dim_customers d
LEFT JOIN activity a ON a.customer_id = d.customer_id
LEFT JOIN support  s ON s.customer_id = d.customer_id
LEFT JOIN txn      t ON t.customer_id = d.customer_id;

-- Unique index so we can REFRESH CONCURRENTLY later.
CREATE UNIQUE INDEX idx_mv_customer_risk_pk
    ON marts.mv_customer_risk_summary(customer_id);


-- =========================================================
--  2. REFRESH PROCEDURE — rebuild the view
-- =========================================================

CREATE OR REPLACE PROCEDURE marts.sp_refresh_customer_risk_summary()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY marts.mv_customer_risk_summary;
END;
$$;


-- =========================================================
--  3. CHURN SCORING PROCEDURE
--  - TRUNCATEs first so re-running doesn't duplicate
--  - LEAST(100, ...) caps the score at 100
-- =========================================================

CREATE OR REPLACE PROCEDURE intelligence.sp_calculate_churn_risk()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE TABLE feature_store.customer_churn_features;

    INSERT INTO feature_store.customer_churn_features (
        customer_id,
        inactivity_days,
        avg_monthly_spend,
        failed_payments,
        support_ticket_count,
        avg_session_duration,
        churn_risk_score,
        risk_level
    )
    WITH scored AS (
        SELECT
            customer_id,
            inactivity_days,
            avg_monthly_spend,
            failed_payments,
            support_ticket_count,
            avg_session_duration,
            LEAST(100, ROUND(
                inactivity_days      * 0.35
                + failed_payments    * 15
                + support_ticket_count * 10
            , 2)) AS churn_risk_score
        FROM marts.mv_customer_risk_summary
    )
    SELECT
        customer_id,
        inactivity_days,
        avg_monthly_spend,
        failed_payments,
        support_ticket_count,
        avg_session_duration,
        churn_risk_score,
        CASE
            WHEN churn_risk_score >= 80 THEN 'HIGH RISK'
            WHEN churn_risk_score >= 50 THEN 'MEDIUM RISK'
            ELSE 'LOW RISK'
        END
    FROM scored;
END;
$$;


-- =========================================================
--  4. REVENUE-AT-RISK PROCEDURE
--  - TRUNCATEs first
--  - Clamps probability to 0-1
-- =========================================================

CREATE OR REPLACE PROCEDURE intelligence.sp_generate_revenue_at_risk()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE TABLE intelligence.revenue_at_risk;

    INSERT INTO intelligence.revenue_at_risk (
        customer_id,
        predicted_churn_probability,
        estimated_monthly_revenue_loss
    )
    SELECT
        customer_id,
        ROUND(LEAST(churn_risk_score, 100) / 100.0, 2),
        ROUND(avg_monthly_spend * (LEAST(churn_risk_score, 100) / 100.0), 2)
    FROM feature_store.customer_churn_features;
END;
$$;


-- =========================================================
--  5. INTERVENTION ENGINE
--  - Only fires for MEDIUM / HIGH risk
--  - Skips customers who already have a PENDING/OPEN intervention
-- =========================================================

CREATE OR REPLACE PROCEDURE intelligence.sp_generate_interventions()
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO intelligence.retention_interventions (
        customer_id,
        intervention_type,
        intervention_priority,
        intervention_status,
        generated_reason
    )
    SELECT
        f.customer_id,
        CASE
            WHEN f.failed_payments >= 2      THEN 'PAYMENT RETRY CAMPAIGN'
            WHEN f.inactivity_days >= 30     THEN 'CUSTOMER RE-ENGAGEMENT'
            WHEN f.support_ticket_count >= 5 THEN 'PRIORITY SUPPORT ESCALATION'
            ELSE                                  'LOYALTY RETENTION OFFER'
        END,
        CASE
            WHEN f.risk_level = 'HIGH RISK'   THEN 'CRITICAL'
            WHEN f.risk_level = 'MEDIUM RISK' THEN 'HIGH'
            ELSE                                   'NORMAL'
        END,
        'PENDING',
        'Auto-generated by decision intelligence engine'
    FROM feature_store.customer_churn_features f
    WHERE f.risk_level <> 'LOW RISK'
      AND NOT EXISTS (
          SELECT 1
          FROM intelligence.retention_interventions r
          WHERE r.customer_id = f.customer_id
            AND r.intervention_status IN ('PENDING', 'OPEN')
      );
END;
$$;