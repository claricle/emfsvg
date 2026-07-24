# TODO 06 — Clip region tracking

**Priority:** P0
**Depends on:** —

## Context

Currently `IntersectClipRect`, `ExcludeClipRect`, `ExtSelectClipRgn`,
`SelectClipPath`, `SetMetArgn`, `OffsetClipRgn` are stubs. The
device context has no clip state.

libemf2svg maintains a clip region as a Path and emits
`<clipPath id="...">` definitions, then applies `clip-path="url(#...)"` to
subsequent elements.

## Outcomes

- `Emfsvg::DeviceContext` gains `clip_path_id` (String or nil).
- `Emfsvg::ClipRegionStack` (new class) tracks clip state across
  SaveDC/RestoreDC.
- `visit_intersect_clip_rect` etc. compute the new clip and emit
  `<defs><clipPath><rect .../></clipPath></defs>`.
- Subsequent drawing records get `clip-path="url(#clip-N)"` attribute.
- `SelectClipPath` uses the current path (@path_d) as the clip shape.

## Files

- `lib/emfsvg/clip_region_stack.rb` (new)
- `lib/emfsvg/device_context.rb` — add clip state
- `lib/emfsvg/svg_builder.rb` — already supports clipPath element
- `lib/emfsvg/visitors/emr_visitor.rb` — implement handlers

## Verification

- Per-record spec on a fixture using IntersectClipRect + drawing.
- Visual: clipped regions match libemf2svg.
