-- ============================================================
-- FILE 01: RESET SCHEMA
-- Completely wipes the public schema to start fresh.
-- ============================================================

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
-- ============================================================
-- FILE 02: ENABLE EXTENSIONS
-- Enables pgcrypto for encryption.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- ============================================================
-- FILE 03: ENUM TYPES
-- Defines reusable ENUM types for statuses.
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'complaint_status') THEN
        CREATE TYPE complaint_status AS ENUM ('pending', 'valid', 'invalid');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attendance_status') THEN
        CREATE TYPE attendance_status AS ENUM ('present', 'absent');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'approval_status') THEN
        CREATE TYPE approval_status AS ENUM ('pending', 'admin_approved', 'rejected');
    END IF;
END$$;
-- ============================================================
-- FILE 04: CORE TABLES
-- Projects, Beneficiaries, BeneficiaryProjects
-- ============================================================

-- Projects
CREATE TABLE Projects (
    project_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    donor TEXT,
    start_date DATE,
    end_date DATE
);

-- Beneficiaries
CREATE TABLE Beneficiaries (
    beneficiary_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    national_id TEXT,
    phone TEXT
);

-- Many-to-many: BeneficiaryProjects
CREATE TABLE BeneficiaryProjects (
    bp_id SERIAL PRIMARY KEY,
    beneficiary_id INT REFERENCES Beneficiaries(beneficiary_id) ON DELETE CASCADE,
    project_id INT REFERENCES Projects(project_id) ON DELETE CASCADE
);

CREATE INDEX idx_bp_beneficiary ON BeneficiaryProjects(beneficiary_id);
CREATE INDEX idx_bp_project ON BeneficiaryProjects(project_id);
-- ============================================================
-- FILE 05: DISTRIBUTION + COMPLAINTS
-- DistributionRounds, Attendance, Complaints
-- ============================================================

-- DistributionRounds
CREATE TABLE DistributionRounds (
    round_id SERIAL PRIMARY KEY,
    project_id INT REFERENCES Projects(project_id) ON DELETE CASCADE,
    date DATE NOT NULL,
    location TEXT NOT NULL
);

CREATE INDEX idx_dr_project ON DistributionRounds(project_id);
CREATE INDEX idx_dr_location ON DistributionRounds(location);

-- Attendance
CREATE TABLE Attendance (
    attendance_id SERIAL PRIMARY KEY,
    round_id INT REFERENCES DistributionRounds(round_id) ON DELETE CASCADE,
    beneficiary_id INT REFERENCES Beneficiaries(beneficiary_id) ON DELETE CASCADE,
    status attendance_status NOT NULL
);

CREATE INDEX idx_att_round ON Attendance(round_id);

-- Complaints
CREATE TABLE Complaints (
    complaint_id SERIAL PRIMARY KEY,
    beneficiary_id INT REFERENCES Beneficiaries(beneficiary_id) ON DELETE CASCADE,
    project_id INT REFERENCES Projects(project_id) ON DELETE CASCADE,
    description TEXT,
    status complaint_status DEFAULT 'pending'
);
-- ============================================================
-- FILE 06: FINANCIALS + DOUBLE-SPENDING TRIGGER
-- ProjectBudgets, Payments, prevent_overspending()
-- ============================================================

-- ProjectBudgets
CREATE TABLE ProjectBudgets (
    budget_id SERIAL PRIMARY KEY,
    project_id INT UNIQUE REFERENCES Projects(project_id) ON DELETE CASCADE,
    allocated_amount NUMERIC(12,2) NOT NULL CHECK (allocated_amount >= 0)
);

-- Payments
CREATE TABLE Payments (
    payment_id SERIAL PRIMARY KEY,
    invoice_id INT,
    project_id INT REFERENCES Projects(project_id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    date DATE DEFAULT CURRENT_DATE,
    approval_status approval_status DEFAULT 'pending'
);

-- Trigger: prevent overspending
CREATE OR REPLACE FUNCTION prevent_overspending()
RETURNS TRIGGER AS $$
DECLARE
    allocated NUMERIC;
    spent NUMERIC;
BEGIN
    SELECT allocated_amount INTO allocated
    FROM ProjectBudgets
    WHERE project_id = NEW.project_id;

    IF allocated IS NULL THEN
        RAISE EXCEPTION 'No budget defined for project %', NEW.project_id;
    END IF;

    SELECT COALESCE(SUM(amount),0) INTO spent
    FROM Payments
    WHERE project_id = NEW.project_id
      AND approval_status = 'admin_approved';

    IF spent + NEW.amount > allocated THEN
        RAISE EXCEPTION 'Payment exceeds remaining project budget';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_overspending
BEFORE INSERT ON Payments
FOR EACH ROW
WHEN (NEW.approval_status = 'admin_approved')
EXECUTE FUNCTION prevent_overspending();
-- ============================================================
-- FILE 07: AUDIT LOG + RLS
-- AuditLog table, audit trigger, RLS policies
-- ============================================================

-- AuditLog
CREATE TABLE AuditLog (
    audit_id SERIAL PRIMARY KEY,
    user_id UUID,
    action TEXT,
    table_name TEXT,
    row_id TEXT,
    old_values JSONB,
    new_values JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_ip TEXT
);

-- Audit trigger for Beneficiaries
CREATE OR REPLACE FUNCTION audit_beneficiaries_update()
RETURNS TRIGGER AS $$
DECLARE
    v_user UUID;
BEGIN
    BEGIN
        v_user := auth.uid();
    EXCEPTION WHEN OTHERS THEN
        v_user := NULL;
    END;

    INSERT INTO AuditLog (user_id, action, table_name, row_id, old_values, new_values, client_ip)
    VALUES (
        v_user,
        TG_OP,
        TG_TABLE_NAME,
        OLD.beneficiary_id::TEXT,
        TO_JSONB(OLD),
        TO_JSONB(NEW),
        inet_client_addr()::TEXT
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_beneficiaries_update
AFTER UPDATE ON Beneficiaries
FOR EACH ROW
EXECUTE FUNCTION audit_beneficiaries_update();

-- Enable RLS
ALTER TABLE DistributionRounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE BeneficiaryProjects ENABLE ROW LEVEL SECURITY;

-- Region-based RLS
CREATE OR REPLACE FUNCTION get_app_region()
RETURNS TEXT AS $$
BEGIN
    RETURN current_setting('app.user_region', true);
END;
$$ LANGUAGE plpgsql STABLE;

CREATE POLICY dist_rounds_region_policy
ON DistributionRounds
FOR SELECT
USING (location = get_app_region());
-- ============================================================
-- FILE 08: MATERIALIZED VIEW + AGGREGATES
-- Daily summary, financial aggregates, attendance aggregates
-- ============================================================

-- Materialized View
CREATE MATERIALIZED VIEW Daily_Distribution_Summary AS
SELECT
    dr.date AS dist_date,
    dr.project_id,
    dr.location,
    COUNT(DISTINCT a.beneficiary_id) AS beneficiaries_served,
    COUNT(DISTINCT dr.round_id) AS rounds_count
FROM DistributionRounds dr
LEFT JOIN Attendance a
    ON dr.round_id = a.round_id
   AND a.status = 'present'
GROUP BY dr.date, dr.project_id, dr.location;

-- Financial Aggregates
CREATE TABLE Financial_Daily_Aggregates AS
SELECT
    project_id,
    date AS pay_date,
    SUM(amount) AS total_spent,
    COUNT(*) AS payments_count
FROM Payments
WHERE approval_status = 'admin_approved'
GROUP BY project_id, date;

-- Attendance Aggregates
CREATE TABLE Attendance_Aggregates AS
SELECT
    dr.round_id,
    dr.project_id,
    SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) AS actual_present
FROM DistributionRounds dr
LEFT JOIN Attendance a
    ON dr.round_id = a.round_id
GROUP BY dr.round_id, dr.project_id;