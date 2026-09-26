-- =========================================================
--  Schemas: the 7 "rooms" of CCIS
-- =========================================================
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS warehouse;
CREATE SCHEMA IF NOT EXISTS marts;
CREATE SCHEMA IF NOT EXISTS feature_store;
CREATE SCHEMA IF NOT EXISTS intelligence;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS monitoring;

-- =========================================================
--  Roles: who can see what
-- =========================================================
CREATE ROLE analyst_role   NOLOGIN;
CREATE ROLE executive_role NOLOGIN;
CREATE ROLE admin_role     NOLOGIN;

-- Everyone must be able to connect
GRANT CONNECT ON DATABASE ccis_platform
    TO analyst_role, executive_role, admin_role;

-- Analysts see the working data
GRANT USAGE ON SCHEMA warehouse, marts, feature_store, intelligence
    TO analyst_role;

-- Executives only see finished dashboards
GRANT USAGE ON SCHEMA marts TO executive_role;

-- Admins see everything
GRANT USAGE ON SCHEMA warehouse, marts, feature_store, intelligence, audit
    TO admin_role;