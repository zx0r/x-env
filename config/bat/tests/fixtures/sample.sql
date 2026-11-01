-- Environment X Syntax Test Fixture: PostgreSQL / SQL
WITH ranked_operations AS (
    SELECT
        session_id,
        command_text,
        execution_duration_ms,
        ROW_NUMBER() OVER (
            PARTITION BY session_id 
            ORDER BY execution_duration_ms DESC
        ) AS rank_in_session
    FROM telemetry.command_history
    WHERE executed_at >= NOW() - INTERVAL '7 days'
      AND status_code = 0
)
SELECT
    r.session_id,
    r.command_text,
    r.execution_duration_ms
FROM ranked_operations r
JOIN auth.sessions s ON s.id = r.session_id
WHERE r.rank_in_session <= 3
ORDER BY r.execution_duration_ms DESC;
