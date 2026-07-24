# TODO 04 — PolyDraw / PolyDraw16: mixed-segment paths

**Priority:** P0
**Depends on:** —

## Context

`EMR_POLYDRAW` and `EMR_POLYDRAW16` carry an array of points plus a
parallel `abTypes[]` array where each byte is one of:

- `PT_MOVETO` (1) — start a new sub-path
- `PT_LINETO` (2) — line to point
- `PT_BEZIERTO` (4) — bezier control point (groups of 3)
- `PT_CLOSEFIGURE` (8) — OR'd with the above; closes the figure

Lower frequency in the corpus but needed for full path support.

## Outcomes

- `visit_poly_draw` walks points + types, emits one `<path>` with
  mixed `M`/`L`/`C`/`Z` commands.
- Both 32-bit and 16-bit variants handled.

## Files

- `lib/emfsvg/visitors/emr_visitor.rb` — two handlers + shared helper

## Verification

- Per-record spec on a fixture containing PolyDraw.
