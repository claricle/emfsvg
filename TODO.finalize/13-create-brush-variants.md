# TODO 13 — Brush variants: CreateMonoBrush, CreateDibPatternBrushPt

**Priority:** P1
**Depends on:** 07 (bitmap records)

## Context

- `EMR_CREATEMONOBRUSH` (93) — creates a monochrome pattern brush
- `EMR_CREATEDIBPATTERNBRUSHPT` (94) — creates a colour DIB pattern brush

Both are used for hatch / pattern fills. The DIB data follows the same
format as bitmap records.

## Outcomes

- `Emf::Emr::Binary::Records::CreateMonoBrush` etc. parse the full
  layout.
- `visit_create_mono_brush` etc. extract the pattern, store in the
  object table as a `Brush` with style=PATTERN.
- `fill_attrs` emits `<pattern>` definitions and `fill="url(#pat-N)"`.

## Files

- Wire classes (emf repo)
- `lib/emfsvg/device_context.rb` — extend Brush
- `lib/emfsvg/visitors/emr_visitor.rb` — handlers + pattern emission

## Verification

- Per-record spec on a fixture using these brush types.
