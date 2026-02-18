CREATE SCHEMA IF NOT EXISTS dwh;

CREATE TABLE dwh.dim_candidates AS SELECT * FROM raw_candidates;
CREATE TABLE dwh.dim_applications AS SELECT * FROM raw_applications;

-- Handling Duplicates
CREATE TABLE dwh.fact_interviews AS
SELECT *
FROM raw_interviews
WHERE interview_id IN (
    SELECT MIN(interview_id) -- keep the earliest entry
    FROM raw_interviews
    GROUP BY app_id, interview_date, outcome
);


CREATE TABLE IF NOT EXISTS dwh.dq_alerts (
    alert_id    SERIAL PRIMARY KEY,
    check_name  VARCHAR(100),
    table_name  VARCHAR(100),
    record_id   INT,
    detail      TEXT,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- Interview date before applied date 
INSERT INTO dwh.dq_alerts (check_name, table_name, record_id, detail)
SELECT 
    'interview_before_application',
    'fact_interviews',
    i.interview_id,
    FORMAT('Interview date %s is before applied date %s', i.interview_date, a.applied_date)
FROM dwh.fact_interviews i
JOIN dwh.dim_applications a ON i.app_id = a.app_id
WHERE i.interview_date < a.applied_date;

-- Decision before Application
INSERT INTO dwh.dq_alerts (check_name, table_name, record_id, detail)
SELECT 
    'decision_before_application',
    'dim_applications',
    app_id,
    FORMAT('Decision date %s is before applied date %s', decision_date, applied_date)
FROM dwh.dim_applications
WHERE decision_date IS NOT NULL 
  AND decision_date < applied_date;

-- App ID doesn't exist
INSERT INTO dwh.dq_alerts (check_name, table_name, record_id, detail)
SELECT 
    'orphaned_interview',
    'fact_interviews',
    interview_id,
    FORMAT('App ID %s not found in applications table', app_id)
FROM dwh.fact_interviews i
WHERE NOT EXISTS (SELECT 1 FROM dwh.dim_applications a WHERE a.app_id = i.app_id);

-- DATA MART VIEW
CREATE OR REPLACE VIEW dwh.dm_hiring_process AS
SELECT

    a.app_id,
    a.role_level,
    a.applied_date,
    a.decision_date,

    c.candidate_id,
    c.full_name AS candidate_name,
    c.source AS candidate_source,

CASE
    WHEN a.decision_date IS NOT NULL
    THEN (a.decision_date - a.applied_date)
END AS time_to_decision_days,
	
    -- Interview outcomes
    COUNT(i.interview_id)                                AS total_interviews,
    COUNT(CASE WHEN i.outcome = 'Passed'   THEN 1 END)  AS passed_interviews,
    COUNT(CASE WHEN i.outcome = 'Rejected' THEN 1 END)  AS rejected_interviews,
    COUNT(CASE WHEN i.outcome = 'No Show'  THEN 1 END)  AS no_show_interviews

FROM dwh.dim_applications  a
JOIN dwh.dim_candidates    c ON a.candidate_id = c.candidate_id

LEFT JOIN dwh.fact_interviews i
       ON i.app_id = a.app_id
      AND i.interview_id NOT IN (
            SELECT record_id
            FROM dwh.dq_alerts
            WHERE table_name = 'fact_interviews'
          )
WHERE a.app_id NOT IN (
    SELECT record_id
    FROM dwh.dq_alerts
    WHERE table_name = 'dim_applications'
)
GROUP BY
    a.app_id, a.role_level, a.applied_date, a.decision_date,
    c.candidate_id, c.full_name, c.source;
