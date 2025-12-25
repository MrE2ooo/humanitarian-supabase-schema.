-- ============================================================
-- FILE 10: SAMPLE DATASET (FULL OUTPUT FOR ALL 4 TEST QUERIES)
-- ============================================================

-- ------------------------------------------------------------
-- 1. PROJECTS
-- ------------------------------------------------------------
INSERT INTO Projects (name, donor, start_date, end_date)
VALUES
    ('Food Assistance', 'WFP', '2025-01-01', '2025-12-31'),
    ('Winterization Support', 'UNHCR', '2025-11-01', '2026-03-01');

-- ------------------------------------------------------------
-- 2. BENEFICIARIES
-- ------------------------------------------------------------
INSERT INTO Beneficiaries (name, address, national_id, phone)
VALUES
    ('Ahmad Ali', 'Latakia - Al-Slaybeh', 'A123456', '099112233'),
    ('Sara Hassan', 'Latakia - Al-Raml', 'B987654', '099445566'),
    ('Yousef Ibrahim', 'Jableh - City Center', 'C555777', '099778899'),
    ('Maya Khaled', 'Latakia - Mashroua', 'D222333', '099667788');

-- ------------------------------------------------------------
-- 3. BENEFICIARY ↔ PROJECT LINKS
-- ------------------------------------------------------------
INSERT INTO BeneficiaryProjects (beneficiary_id, project_id)
VALUES
    (1, 1),
    (2, 1),
    (4, 1),
    (3, 2);

-- ------------------------------------------------------------
-- 4. DISTRIBUTION ROUNDS
-- ------------------------------------------------------------
INSERT INTO DistributionRounds (project_id, date, location)
VALUES
    (1, '2025-01-10', 'Latakia'),
    (1, '2025-01-15', 'Latakia'),
    (2, '2025-12-01', 'Jableh');

-- ------------------------------------------------------------
-- 5. ATTENDANCE (ensures Attendance_Aggregates + MV have output)
-- ------------------------------------------------------------
INSERT INTO Attendance (round_id, beneficiary_id, status)
VALUES
    (1, 1, 'present'),
    (1, 2, 'present'),
    (1, 4, 'absent'),
    (2, 1, 'present'),
    (2, 4, 'present'),
    (3, 3, 'present');

-- ------------------------------------------------------------
-- 6. COMPLAINTS (ensures Complaints table has output)
-- ------------------------------------------------------------
INSERT INTO Complaints (beneficiary_id, project_id, description, status)
VALUES
    (1, 1, 'Did not receive full food basket', 'pending'),
    (4, 1, 'Incorrect family size recorded', 'valid');

-- ------------------------------------------------------------
-- 7. PROJECT BUDGETS (required for Payments)
-- ------------------------------------------------------------
INSERT INTO ProjectBudgets (project_id, allocated_amount)
VALUES
    (1, 50000),
    (2, 30000);

-- ------------------------------------------------------------
-- 8. PAYMENTS (ensures Financial_Daily_Aggregates has output)
-- ------------------------------------------------------------
INSERT INTO Payments (invoice_id, project_id, amount, approval_status, date)
VALUES
    (101, 1, 5000, 'admin_approved', '2025-01-10'),
    (102, 1, 2500, 'admin_approved', '2025-01-15'),
    (201, 2, 4000, 'admin_approved', '2025-12-01');

-- DO NOT UNCOMMENT THIS unless testing overspending:
-- INSERT INTO Payments (invoice_id, project_id, amount, approval_status)
-- VALUES (999, 1, 999999, 'admin_approved');

-- ------------------------------------------------------------
-- 9. REBUILD AGGREGATION TABLES (ensures output)
-- ------------------------------------------------------------

-- Financial aggregates
TRUNCATE Financial_Daily_Aggregates;
INSERT INTO Financial_Daily_Aggregates
SELECT
    project_id,
    date AS pay_date,
    SUM(amount) AS total_spent,
    COUNT(*) AS payments_count
FROM Payments
WHERE approval_status = 'admin_approved'
GROUP BY project_id, date;

-- Attendance aggregates
TRUNCATE Attendance_Aggregates;
INSERT INTO Attendance_Aggregates
SELECT
    dr.round_id,
    dr.project_id,
    SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) AS actual_present
FROM DistributionRounds dr
LEFT JOIN Attendance a ON dr.round_id = a.round_id
GROUP BY dr.round_id, dr.project_id;

-- ------------------------------------------------------------
-- 10. REFRESH MATERIALIZED VIEW
-- ------------------------------------------------------------
REFRESH MATERIALIZED VIEW Daily_Distribution_Summary;

-- ============================================================
-- END OF SAMPLE DATASET
-- ============================================================