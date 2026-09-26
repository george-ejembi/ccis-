-- =========================================================
--  INJECT UNHEALTHY CUSTOMERS
--  Create ~60 customers with realistic churn signals:
--  dormant accounts, repeated payment failures, ticket floods.
-- =========================================================

-- Dormant customers — no activity for 60-180 days
INSERT INTO warehouse.fact_customer_activity
    (activity_id, customer_id, activity_date,
     session_duration_minutes, login_count, feature_used)
SELECT
    gen_random_uuid(),
    c.customer_id,
    CURRENT_DATE - (60 + (random()*120)::INT),   -- 60-180 days ago
    (random()*5)::INT,                            -- very short sessions
    0,
    'Login'
FROM warehouse.dim_customers c
WHERE c.customer_sk % 8 = 0;    -- every 8th customer is dormant

-- Repeat payment failures for those same customers
INSERT INTO warehouse.fact_transactions
    (transaction_id, customer_id, transaction_date, amount,
     payment_status, subscription_type)
SELECT
    gen_random_uuid(),
    c.customer_id,
    CURRENT_DATE - (random()*90)::INT,
    49.99,
    'FAILED',
    'Basic'
FROM warehouse.dim_customers c
CROSS JOIN generate_series(1, 4)
WHERE c.customer_sk % 8 = 0;

-- Ticket floods for another group
INSERT INTO warehouse.fact_support_interactions
    (ticket_id, customer_id, ticket_date, issue_category,
     priority_level, resolution_status, resolution_hours)
SELECT
    gen_random_uuid(),
    c.customer_id,
    CURRENT_DATE - (random()*60)::INT,
    'Technical',
    'MEDIUM',
    'RESOLVED',
    (random()*72)::INT
FROM warehouse.dim_customers c
CROSS JOIN generate_series(1, 6)
WHERE c.customer_sk % 11 = 0;   -- every 11th customer