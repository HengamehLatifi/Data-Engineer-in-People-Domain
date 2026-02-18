-- METRIC 1: Monthly Active Pipeline
WITH month_spine AS (
    SELECT DATE_TRUNC('month', gs)::DATE AS report_month
    FROM generate_series(
        (SELECT DATE_TRUNC('month', MIN(applied_date)) FROM dwh.dim_applications),
        (SELECT DATE_TRUNC('month', MAX(COALESCE(decision_date, CURRENT_DATE))) FROM dwh.dim_applications),
        INTERVAL '1 month'
    ) gs
)
SELECT
    m.report_month,
    COUNT(a.app_id) AS active_applications
FROM month_spine m
JOIN dwh.dim_applications a
    ON  m.report_month >= DATE_TRUNC('month', a.applied_date)
    AND m.report_month <= DATE_TRUNC('month', COALESCE(a.decision_date, CURRENT_DATE))
WHERE a.app_id NOT IN (
    SELECT record_id FROM dwh.dq_alerts WHERE table_name = 'dim_applications'
)
GROUP BY m.report_month
ORDER BY m.report_month;


-- METRIC 2: Cumulative Hires by Source
WITH hires AS (
    SELECT
        c.source,
        DATE_TRUNC('month', a.decision_date)::DATE AS hire_month
    FROM dwh.dim_applications a
    JOIN dwh.dim_candidates c ON a.candidate_id = c.candidate_id
    WHERE a.decision_date IS NOT NULL
      AND a.app_id NOT IN (
            SELECT record_id FROM dwh.dq_alerts WHERE table_name = 'dim_applications'
      )
      AND EXISTS (
            SELECT 1 FROM dwh.fact_interviews i
            WHERE i.app_id  = a.app_id
              AND i.outcome = 'Passed'
              AND i.interview_id NOT IN (
                    SELECT record_id FROM dwh.dq_alerts WHERE table_name = 'fact_interviews'
              )
      )
)
SELECT
    hire_month,
    source,
    COUNT(*)                                              AS hires_this_month,
    SUM(COUNT(*)) OVER (PARTITION BY source ORDER BY hire_month) AS cumulative_hires
FROM hires
GROUP BY hire_month, source
ORDER BY source, hire_month;