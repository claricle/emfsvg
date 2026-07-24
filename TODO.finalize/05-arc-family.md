# TODO 05 — Arc family: Arc / ArcTo / Chord / Pie

**Priority:** P0
**Depends on:** 12 (SetArcDirection)

## Context

`EMR_ARC`, `EMR_ARCTO`, `EMR_CHORD`, `EMR_PIE` all share the same
wire layout (rclBox + ptlStart + ptlEnd) but produce different
output:

- **Arc**: just the arc curve (open)
- **ArcTo**: arc appended to current path (no closing)
- **Chord**: arc + line connecting endpoints (closed)
- **Pie**: arc + lines from endpoints to rclBox centre (closed wedge)

The arc is parametrised by an ellipse inscribed in rclBox, starting
at the ray from centre through ptlStart, ending at the ray through
ptlEnd. Direction (clockwise/counter-clockwise) is controlled by
`SetArcDirection`.

## Outcomes

- New helper `arc_path(rcl_box, ptl_start, ptl_end, mode)` returning
  SVG path data using `A` (arc) commands.
- All four record types dispatch to it with different close behavior.
- Honours `@dc.arc_direction` (default counter-clockwise per GDI).

## Files

- `lib/emfsvg/visitors/emr_visitor.rb` — handlers + helper
- `lib/emfsvg/device_context.rb` — add `arc_direction` accessor (default 1)

## Verification

- Per-record spec with synthetic input.
- Visual: arc shapes match libemf2svg's rendering (modulo numerical
  precision).

## Notes

SVG arc commands (`A rx ry x-rot large-arc sweep x y`) map well to
GDI arcs once you compute the sweep flags from the start/end angles.
