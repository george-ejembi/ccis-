-- =========================================================
--  1. AUDIT TRIGGER
--  Handles INSERT, UPDATE, and DELETE safely.
-- =========================================================

CREATE OR REPLACE FUNCTION audit.fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_ref TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_ref := OLD.customer_id::TEXT;
    ELSE
        v_ref := NEW.customer_id::TEXT;
    END IF;

    INSERT INTO audit.audit_log (
        table_name,
        operation_type,
        changed_by,
        record_reference
    )
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CURRENT_USER,
        v_ref
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_customer_updates ON warehouse.dim_customers;

CREATE TRIGGER trg_audit_customer_updates
AFTER INSERT OR UPDATE OR DELETE
ON warehouse.dim_customers
FOR EACH ROW
EXECUTE FUNCTION audit.fn_audit_trigger();


-- =========================================================
--  2. SUPPORT ESCALATION TRIGGER
--  A HIGH-priority ticket auto-opens a CRITICAL intervention.
-- =========================================================

CREATE OR REPLACE FUNCTION intelligence.fn_support_escalation()
RETURNS TRIGGER
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
    VALUES (
        NEW.customer_id,
        'SUPPORT ESCALATION',
        'CRITICAL',
        'OPEN',
        'High-priority support ticket detected on ' || NEW.ticket_date
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_escalation ON warehouse.fact_support_interactions;

CREATE TRIGGER trg_support_escalation
AFTER INSERT
ON warehouse.fact_support_interactions
FOR EACH ROW
WHEN (NEW.priority_level = 'HIGH')
EXECUTE FUNCTION intelligence.fn_support_escalation();