# TODO 14 — Escape records

**Priority:** P2
**Depends on:** —

## Context

`DrawEscape`, `ExtEscape`, `NamedEscape` carry device-driver-specific
data. They are typically no-ops for SVG output but should be parsed
and silently ignored (not dropped with a warning).

## Outcomes

- All three registered in `HANDLERS` with no-op handlers.

## Files

- `lib/emfsvg/visitors/emr_visitor.rb`

## Verification

- No warnings in verbose mode for these records.
