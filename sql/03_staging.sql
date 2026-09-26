-- =========================================================
--  STAGING LAYER — raw, unmodified source data
-- =========================================================

CREATE TABLE staging.raw_customers (
    customer_id         UUID PRIMARY KEY,
    full_name           VARCHAR(255),
    gender              VARCHAR(50),
    age                 INT,
    country             VARCHAR(100),
    city                VARCHAR(100),
    signup_date         DATE,
    acquisition_channel VARCHAR(100),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.raw_transactions (
    transaction_id    UUID PRIMARY KEY,
    customer_id       UUID,
    transaction_date  DATE,
    amount            NUMERIC(12,2),
    payment_status    VARCHAR(50),
    subscription_type VARCHAR(100),
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.raw_customer_activity (
    activity_id              UUID PRIMARY KEY,
    customer_id              UUID,
    activity_date            DATE,
    session_duration_minutes INT,
    login_count              INT,
    feature_used             VARCHAR(255),
    created_at               TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.raw_support_tickets (
    ticket_id         UUID PRIMARY KEY,
    customer_id       UUID,
    ticket_date       DATE,
    issue_category    VARCHAR(255),
    priority_level    VARCHAR(50),
    resolution_status VARCHAR(50),
    resolution_hours  INT,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);