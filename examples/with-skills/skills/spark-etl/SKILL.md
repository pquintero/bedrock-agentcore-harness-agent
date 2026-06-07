# Spark ETL

Patterns for writing and reviewing PySpark ETL/ELT jobs.

## When to use
Use this skill when the user works with PySpark transformations, joins,
aggregations, or troubleshoots Spark performance.

## Guidance
- Read once, transform with the DataFrame API; avoid collecting to the driver.
- Prefer broadcast joins when one side is small (`broadcast(df)`); otherwise
  ensure both sides are partitioned on the join key to avoid skew.
- Repartition before wide operations; coalesce before writing to control output
  file count.
- Push filters and column pruning as early as possible (predicate/projection
  pushdown).
- Write columnar (Parquet/Delta) with partitioning that matches query filters;
  avoid high-cardinality partition columns.
- Make jobs idempotent: overwrite by partition or use merge/upsert.

## Checklist
- [ ] No unnecessary `.collect()` / `.toPandas()` on large data
- [ ] Join strategy chosen deliberately (broadcast vs. sort-merge)
- [ ] Output partitioning matches downstream read patterns
- [ ] Schema is explicit (no surprise inference in production)
