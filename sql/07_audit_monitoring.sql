-- =========================================================
--  AUDIT LOG — immutable trail of changes
-- =========================================================

CREATE TABLE audit.audit_log (
    audit_id         BIGSERIAL PRIMARY KEY,
    table_name       VARCHAR(255),
    operation_type   VARCHAR(50),
    changed_by       VARCHAR(255),
    changed_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    record_reference TEXT
);

-- =========================================================
--  MONITORING — pipeline runtime telemetry
-- =========================================================

CREATE TABLE monitoring.query_performance_logs (
    log_id            BIGSERIAL PRIMARY KEY,
    query_name        VARCHAR(255),
    execution_time_ms NUMERIC(12,2),
    logged_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);