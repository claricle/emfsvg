# TODO 10 — GradientFill

**Priority:** P1
**Depends on:** —

## Context

`EMR_GRADIENTFILL` (type 118) carries an array of `TRIVERTEX` structs
(positions + colours) and an array of gradient rectangles or
triangles. Modes:

- `GRADIENT_FILL_RECT_H` (0) — horizontal linear
- `GRADIENT_FILL_RECT_V` (1) — vertical linear
- `GRADIENT_FILL_TRIANGLE` (2) — barycentric

8 occurrences in the corpus.

## Outcomes

- `Emf::Emr::Binary::Records::GradientFill` parses the full layout
  (currently stubbed).
- `visit_gradient_fill` emits `<linearGradient>` definitions and
  `<rect>`/`<polygon>` elements with `fill="url(#grad-N)"`.

## Files

- Wire class (emf repo)
- `lib/emfsvg/visitors/emr_visitor.rb` — handler

## Verification

- Per-record spec; visual check.
