# TODO 08 — Region operations: FillRgn, FrameRgn, InvertRgn, PaintRgn

**Priority:** P1
**Depends on:** 06 (clip region tracking)

## Context

Region operations act on a `RGNDATA` structure (a header + array of
RECTLs). Each one does something different:

- `FillRgn` — fill the region with a brush
- `FrameRgn` — draw a border of given thickness around the region
- `InvertRgn` — invert the colours (SVG: use `filter: invert()`)
- `PaintRgn` — fill with current brush using current ROP

Low frequency in the corpus but completes the region API.

## Outcomes

- `Emf::Emr::Binary::Records::FillRgn` etc. parse the RGNDATA structure
  (currently stubbed with `uint32 :ih_brush; rest :body`).
- `visit_fill_rgn` etc. walk the rectangle array, emit a `<path>` with
  the region shape.

## Files

- Wire classes (emf repo) — full layout
- `lib/emfsvg/visitors/emr_visitor.rb` — handlers

## Verification

- Per-record spec; visual check.
