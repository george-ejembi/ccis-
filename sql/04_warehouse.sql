-- =========================================================
--  WAREHOUSE — dimensions and facts
-- =========================================================

-- ---------------------------------------------------------
--  Dimension: customers (SCD-style — one row per customer)
-- ---------------------------------------------------------
CREATE TABLE warehouse.dim_customers (
    customer_sk        SERIAL PRIMARY KEY,
    customer_id        UUID UNIQUE NOT NULL,
    full_name          VARCHAR(255),
    gender             VARCHAR(50),
    age                INT,
    country            VARCHAR(100),
    city               VARCHAR(100),
    signup_date        DATE,
    acquisition_channel VARCHAR(100),
    customer_status    VARCHAR(50) DEFAULT 'ACTIVE',
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------
--  Fact: transactions (RANGE PARTITIONED by date)
-- ---------------------------------------------------------
CREATE TABLE warehouse.fact_transactions (
    transaction_sk    BIGSERIAL,
    transaction_id    UUID NOT NULL,
    customer_id       UUID NOT NULL,
    transaction_date  DATE NOT NULL,
    amount            NUMERIC(12,2),
    payment_status    VARCHAR(50),
    subscription_type VARCHAR(100),
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_sk, transaction_date)   -- must include partition key
)
PARTITION BY RANGE (transaction_date);

-- ---------------------------------------------------------
--  Auto-partition helper
--  Call this for any month you need; it creates the partition
--  only if it doesn't already exist. Idempotent.
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION warehouse.fn_create_monthly_partition(p_month DATE)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_start DATE := date_trunc('month', p_month)::DATE;
    v_end   DATE := (date_trunc('month', p_month) + INTERVAL '1 month')::DATE;
    v_name  TEXT := 'fact_transactions_' || to_char(v_start, 'YYYY_MM');
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'warehouse' AND c.relname = v_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE warehouse.%I PARTITION OF warehouse.fact_transactions
             FOR VALUES FROM (%L) TO (%L)',
            v_name, v_start, v_end
        );
        RAISE NOTICE 'Created partition %', v_name;
    END IF;
END;
$$;

-- ---------------------------------------------------------
--  Generate partitions from 2024-01 through 2027-12
-- ---------------------------------------------------------
DO $$
DECLARE m DATE;
BEGIN
    FOR m IN
        SELECT generate_series(
            DATE '2024-01-01',
            DATE '2027-12-01',
            INTERVAL '1 month'
        )::DATE
    LOOP
        PERFORM warehouse.fn_create_monthly_partition(m);
    END LOOP;
END $$;

-- ---------------------------------------------------------
--  Fact: customer activity (one row per activity event)
-- ---------------------------------------------------------
CREATE TABLE warehouse.fact_customer_activity (
    activity_sk              BIGSERIAL PRIMARY KEY,
    activity_id              UUID UNIQUE,
    customer_id              UUID,
    activity_date            DATE,
    session_duration_minutes INT,
    login_count              INT,
    feature_used             VARCHAR(255),
    created_at               TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------
--  Fact: support interactions
-- ---------------------------------------------------------
CREATE TABLE warehouse.fact_support_interactions (
    support_sk        BIGSERIAL PRIMARY KEY,
    ticket_id         UUID UNIQUE,
    customer_id       UUID,
    ticket_date       DATE,
    issue_category    VARCHAR(255),
    priority_level    VARCHAR(50),
    resolution_status VARCHAR(50),
    resolution_hours  INT,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);