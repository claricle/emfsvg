# TODO 15 — Investigate the 3539 unknown-type Raw records

**Priority:** P0
**Depends on:** —

## Context

The profile shows 3539 records fall through to `Raw` (unknown type).
These are records whose `iType` is not in our registry. Either:

1. They are public/spool comment subtypes that share type id 70
   (`EMR_COMMENT`) and need to be dispatched by their inner comment
   identifier.
2. They are rare record types we missed.
3. They are non-standard extensions.

## Outcomes

- Run a profiling pass to bucket the 3539 Raw records by `iType`.
- For each significant bucket:
  - If it's a comment subtype, add proper dispatch.
  - If it's a known record we missed, add a wire class + handler.
  - If it's truly unknown, document in `docs/compatibility_matrix.adoc`.
- Re-run profile; Raw count should drop to near zero.

## Files

- `lib/emf/emr/binary/type_codes.rb` (emf repo) — add any missing codes
- `lib/emf/emr/binary/records.rb` (emf repo) — register missing types

## Verification

- Compat matrix: Raw count drops substantially.
