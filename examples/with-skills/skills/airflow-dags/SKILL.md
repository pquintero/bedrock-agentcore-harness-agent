# Airflow DAGs

Conventions for authoring and reviewing Apache Airflow DAGs.

## When to use
Use this skill when the user builds, schedules, or debugs Airflow pipelines.

## Guidance
- Keep tasks idempotent and atomic; design for safe retries and backfills.
- Pass data between tasks via storage (S3, tables), not large XComs.
- Use `data_interval_start`/`logical_date` for partitioned, deterministic runs;
  avoid `datetime.now()` in task logic.
- Set explicit `retries`, `retry_delay`, and sensible `sla`; fail fast on bad
  input.
- Prefer deferrable operators/sensors to free up worker slots while waiting.
- Keep DAG parsing lightweight: no heavy imports or API calls at module top
  level.

## Checklist
- [ ] Tasks are idempotent and backfill-safe
- [ ] No business logic depends on wall-clock time
- [ ] Retries and alerting configured
- [ ] DAG file parses quickly (no top-level heavy work)
