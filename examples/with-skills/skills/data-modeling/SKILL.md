# Data Modeling

Conventions and heuristics for designing analytical data models.

## When to use
Use this skill when the user asks to design tables, choose keys, model
dimensions/facts, or decide on normalization vs. denormalization.

## Guidance
- Prefer a star schema for analytical workloads: narrow fact tables with
  foreign keys to conformed dimensions.
- Use surrogate keys for dimensions; keep natural/business keys as attributes.
- Model slowly changing dimensions explicitly (SCD type 1 vs. type 2) and state
  the tradeoff (history vs. storage/complexity).
- Choose grain first: state the fact table grain in one sentence before adding
  columns.
- Name tables and columns in snake_case; suffix facts with `_fact` and
  dimensions with `_dim`.

## Checklist before finalizing
- [ ] Grain is explicit and unambiguous
- [ ] Every fact measure is additive, semi-additive, or non-additive (labeled)
- [ ] Dimensions are conformed where shared across facts
- [ ] Partition/clustering strategy stated for large tables
