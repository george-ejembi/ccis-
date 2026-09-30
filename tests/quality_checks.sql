-- =========================================================
--  CCIS DATA QUALITY CHECKS
--  Each block asserts an invariant. Any failure raises an
--  exception and stops execution.
--
--  Run:
--    psql -U postgres -d ccis_platform -f tests/quality_checks.sql
--
--  Expected output: "ALL CHECKS PASSED" at the end.
-- =========================================================

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_count INTEGER;
    v_max   NUMERIC;
    v_min   NUMERIC;
BEGIN
    RAISE NOTICE 'Running CCIS quality checks...';

    -- -----------------------------------------------------
    -- [1] Every customer in dim_customers has a feature row
    -- -----------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM warehouse.dim_customers d
    WHERE NOT EXISTS (
        SELECT 1 FROM feature_store.customer_churn_features f
        WHERE f.customer_id = d.customer_id
    );

    IF v_count > 0 THEN
        RAISE EXCEPTION 'FAIL [1]: % customers have no churn feature row', v_count;
    END IF;
    RAISE NOTICE '  PASS [1] all customers have a churn feature row';


    -- -----------------------------------------------------
    -- [2] churn_risk_score is between 0 and 100
    -- -----------------------------------------------------
    SELECT MAX(churn_risk_score), MIN(churn_risk_score)
    INTO v_max, v_min
    FROM feature_store.customer_churn_features;

    IF v_max IS NULL OR v_max > 100 OR v_min < 0 THEN
        RAISE EXCEPTION 'FAIL [2]: churn_risk_score out of range (min=%, max=%)', v_min, v_max;
    END IF;
    RAISE NOTICE '  PASS [2] churn_risk_score in range [%, %]', v_min, v_max;


    -- -----------------------------------------------------
    -- [3] predicted_churn_probability is between 0 and 1
    -- -----------------------------------------------------
    SELECT MAX(predicted_churn_probability), MIN(predicted_churn_probability)
    INTO v_max, v_min
    FROM intelligence.revenue_at_risk;

    IF v_max IS NULL OR v_max > 1 OR v_min < 0 THEN
        RAISE EXCEPTION 'FAIL [3]: probability out of range (min=%, max=%)', v_min, v_max;
    END IF;
    RAISE NOTICE '  PASS [3] predicted_churn_probability in range [%, %]', v_min, v_max;


    -- -----------------------------------------------------
    -- [4] risk_level is one of the three allowed values
    -- -----------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM feature_store.customer_churn_features
    WHERE risk_level NOT IN ('LOW RISK', 'MEDIUM RISK', 'HIGH RISK');

    IF v_count > 0 THEN
        RAISE EXCEPTION 'FAIL [4]: % rows have invalid risk_level', v_count;
    END IF;
    RAISE NOTICE '  PASS [4] all risk_level values valid';


    -- -----------------------------------------------------
    -- [5] intervention_priority is one of the allowed values
    -- -----------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM intelligence.retention_interventions
    WHERE intervention_priority NOT IN ('CRITICAL', 'HIGH', 'NORMAL');

    IF v_count > 0 THEN
        RAISE EXCEPTION 'FAIL [5]: % interventions have invalid priority', v_count;
    END IF;
    RAISE NOTICE '  PASS [5] all intervention_priority values valid';


    -- -----------------------------------------------------
    -- [6] No duplicate customer_id in feature_store
    -- -----------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM (
        SELECT customer_id
        FROM feature_store.customer_churn_features
        GROUP BY customer_id
        HAVING COUNT(*) > 1
    ) dupes;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'FAIL [6]: % customers appear multiple times in feature_store', v_count;
    END IF;
    RAISE NOTICE '  PASS [6] no duplicate customers in feature_store';


    -- -----------------------------------------------------
    -- [7] Every transaction belongs to a known customer
    -- -----------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM warehouse.fact_transactions t
    WHERE NOT EXISTS (
        SELECT 1 FROM warehouse.dim_customers d
        WHERE d.customer_id = t.customer_id
    );

    IF v_count > 0 THEN
        RAISE EXCEPTION 'FAIL [7]: % transactions reference unknown customers', v_count;
    END IF;
    RAISE NOTICE '  PASS [7] all transactions reference known customers';


    -- -----------------------------------------------------
    -- [8] No negative transaction amounts
    -- -----------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM warehouse.fact_transactions
    WHERE amount < 0;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'FAIL [8]: % transactions have negative amount', v_count;
    END IF;
    RAISE NOTICE '  PASS [8] no negative transaction amounts';


    -- -----------------------------------------------------
    -- [9] audit_log has at least one entry per customer insert
    -- -----------------------------------------------------
    SELECT COUNT(*) INTO v_count FROM audit.audit_log;

    IF v_count < (SELECT COUNT(*) FROM warehouse.dim_customers) THEN
        RAISE EXCEPTION 'FAIL [9]: audit_log has % rows but dim_customers has %',
            v_count, (SELECT COUNT(*) FROM warehouse.dim_customers);
    END IF;
    RAISE NOTICE '  PASS [9] audit_log is populated (% rows)', v_count;


    -- -----------------------------------------------------
    -- [10] All 48 monthly partitions exist
    -- -----------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'warehouse'
      AND c.relname LIKE 'fact_transactions_%';

    IF v_count < 48 THEN
        RAISE EXCEPTION 'FAIL [10]: only % partitions exist (expected 48)', v_count;
    END IF;
    RAISE NOTICE '  PASS [10] all % monthly partitions exist', v_count;


    -- -----------------------------------------------------
    -- ALL PASSED
    -- -----------------------------------------------------
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '  ALL CHECKS PASSED';
    RAISE NOTICE '================================================';

END $$;