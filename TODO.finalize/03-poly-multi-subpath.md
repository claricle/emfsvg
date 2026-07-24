# TODO 03 — PolyPolygon / PolyPolygon16 / PolyPolyline / PolyPolyline16

**Priority:** P0
**Depends on:** —

## Context

Multi-subpath polygon/polyline records. Each carries N sub-paths in
one record, with `aPolyCounts[i]` giving the point count for sub-path i.

47 records in the corpus (41 PolyPolygon16 + 6 PolyPolyline16). Low
count but common in real-world EMFs from Office and Visio.

## Outcomes

- `visit_poly_polygon` walks sub-paths, emits one `<path>` per sub-path
  with `Z` close (for polygons) or open (for polylines).
- All four variants (32-bit/16-bit × polygon/polyline) handled.
- Per-sub-path bounds inferred from points (libemf2svg doesn't emit
  per-subpath bounds either).

## Files

- `lib/emfsvg/visitors/emr_visitor.rb` — four handlers + shared helper

## Verification

- Per-record spec on a fixture containing PolyPolygon16.
- Compat matrix: byte ratio rises for those fixtures.
