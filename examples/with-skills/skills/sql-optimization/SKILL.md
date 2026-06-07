# SQL Optimization

Heuristics for writing and tuning analytical SQL.

## When to use
Use this skill when the user writes, reviews, or tunes SQL queries, or asks why
a query is slow or expensive.

## Guidance
- Select only the columns needed; avoid `SELECT *` in pipelines.
- Filter early and on partition/cluster keys to enable pruning.
- Replace correlated subqueries with joins or window functions where possible.
- Pre-aggregate before joining when it reduces row counts.
- Watch for join fan-out (one-to-many) that silently multiplies measures.
- For warehouses, prefer `QUALIFY` with window functions over self-joins for
  top-N-per-group.

## Checklist
- [ ] Query reads only required columns and partitions
- [ ] No accidental cross/fan-out joins
- [ ] Aggregations happen at the smallest viable grain
- [ ] Explain plan reviewed for full scans on large tables
