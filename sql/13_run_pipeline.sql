-- =========================================================
--  FULL PIPELINE
--  Run in this exact order — each step depends on the previous.
-- =========================================================

-- 1. Rebuild the feature source (materialized view)
CALL marts.sp_refresh_customer_risk_summary();

-- 2. Score every customer for churn risk
CALL intelligence.sp_calculate_churn_risk();

-- 3. Translate scores into ₦ / $ exposure
CALL intelligence.sp_generate_revenue_at_risk();

-- 4. Decide retention actions for at-risk customers
CALL intelligence.sp_generate_interventions();