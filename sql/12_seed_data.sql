-- =========================================================
--  SEED DATA — realistic volume to prove the pipeline works
--  500 customers, ~2500 transactions, ~4000 activity rows,
--  ~1000 support tickets. Takes about 5 seconds.
-- =========================================================

-- 1. Customers --------------------------------------------------
INSERT INTO warehouse.dim_customers
    (customer_id, full_name, gender, age, country, city,
     signup_date, acquisition_channel)
SELECT
    gen_random_uuid(),
    'Customer ' || g,
    (ARRAY['Male','Female'])[1 + (g % 2)],
    18 + (g % 50),
    (ARRAY['Nigeria','Ghana','Kenya','South Africa'])[1 + (g % 4)],
    (ARRAY['Lagos','Accra','Nairobi','Cape Town'])[1 + (g % 4)],
    CURRENT_DATE - make_interval(days => g % 730),
    (ARRAY['Facebook Ads','Google Ads','Referral','Organic'])[1 + (g % 4)]
FROM generate_series(1, 500) AS g;


-- 2. Transactions (~5 per customer over the last 180 days) ------
INSERT INTO warehouse.fact_transactions
    (transaction_id, customer_id, transaction_date, amount,
     payment_status, subscription_type)
SELECT
    gen_random_uuid(),
    c.customer_id,
    CURRENT_DATE - (random() * 180)::INT,
    ROUND((random() * 200 + 10)::NUMERIC, 2),
    CASE WHEN random() < 0.12 THEN 'FAILED' ELSE 'SUCCESS' END,
    (ARRAY['Basic','Premium','Enterprise'])[1 + floor(random()*3)::INT]
FROM warehouse.dim_customers c
CROSS JOIN generate_series(1, 5);


-- 3. Customer activity (~8 events per customer) -----------------
INSERT INTO warehouse.fact_customer_activity
    (activity_id, customer_id, activity_date,
     session_duration_minutes, login_count, feature_used)
SELECT
    gen_random_uuid(),
    c.customer_id,
    CURRENT_DATE - (random() * 120)::INT,
    (random() * 60)::INT,
    (random() * 10)::INT,
    (ARRAY['Dashboard','Reports','Billing','Settings'])[1 + floor(random()*4)::INT]
FROM warehouse.dim_customers c
CROSS JOIN generate_series(1, 8);


-- 4. Support tickets (~2 per customer) --------------------------
--    Note: HIGH priority tickets will auto-trigger an intervention
--    from trg_support_escalation. Expect ~330 CRITICAL rows here
--    before the pipeline even runs.
INSERT INTO warehouse.fact_support_interactions
    (ticket_id, customer_id, ticket_date, issue_category,
     priority_level, resolution_status, resolution_hours)
SELECT
    gen_random_uuid(),
    c.customer_id,
    CURRENT_DATE - (random() * 90)::INT,
    (ARRAY['Billing','Technical','Account','Other'])[1 + floor(random()*4)::INT],
    (ARRAY['LOW','MEDIUM','HIGH'])[1 + floor(random()*3)::INT],
    'RESOLVED',
    (random() * 48)::INT
FROM warehouse.dim_customers c
CROSS JOIN generate_series(1, 2);