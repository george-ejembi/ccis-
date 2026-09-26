-- =========================================================
--  EXECUTIVE MART — for Power BI / executive dashboards
-- =========================================================

CREATE OR REPLACE VIEW marts.vw_executive_churn_dashboard AS
SELECT
    risk_level,
    COUNT(*)                              AS customer_count,
    ROUND(AVG(churn_risk_score), 2)       AS avg_risk_score,
    ROUND(SUM(avg_monthly_spend), 2)      AS monthly_revenue_exposure,
    ROUND(SUM(avg_monthly_spend) * 12, 2) AS annual_revenue_exposure
FROM feature_store.customer_churn_features
GROUP BY risk_level;