# TODO 02 — ExtCreatePen: geometric pens with custom styles

**Priority:** P0
**Depends on:** —

## Context

`EMR_EXTCREATEPEN` (type 95) creates a "geometric pen" with much
richer styling than `EMR_CREATEPEN`:

- Custom line styles (user-defined dash patterns)
- Line caps (round, square, flat) and joins (round, bevel, miter)
- Custom start/end caps via CustomLineCap objects
- Brush-style fills (the pen stroke itself can be hatched or patterned)
- Transformation matrix on the pen nib

474 occurrences in the corpus.

## Outcomes

- `Emf::Emr::Binary::Records::ExtCreatePen` parses the full wire layout
  (currently stubbed with `uint32 :ih_pen; rest :body`).
- `Emfsvg::Pen` extended with:
  - `line_cap`, `line_join`, `dash_pattern` (Array<Integer>)
  - `transform` (Matrix for the pen nib)
- `visit_ext_create_pen` constructs the Pen and stores it.
- `stroke_attrs` emits `stroke-linecap`, `stroke-linejoin`,
  `stroke-dasharray` from the pen.

## Files

- `lib/emf/emr/binary/records/ext_create_pen.rb` (emf repo)
- `lib/emfsvg/device_context.rb` — extend Pen
- `lib/emfsvg/visitors/emr_visitor.rb` — handler + stroke_attrs

## Verification

- Per-record spec: parse a known ExtCreatePen record, verify Pen
  attributes.
- Round-trip in emf: 208/208 still byte-identical.
- Compat matrix: dash patterns appear in emfsvg output where libemf2svg
  emits them.
