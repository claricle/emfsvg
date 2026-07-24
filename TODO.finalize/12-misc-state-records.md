# TODO 12 — Misc state records

**Priority:** P2
**Depends on:** —

## Context

A handful of state-only records need handlers for completeness.
None emit visual output; they update `DeviceContext` state.

- `SetBrushOrgEx` — set brush pattern origin
- `SetMapperFlags` — font mapper flags
- `SetStretchBltMode` — already registered
- `SetLayout` — RTL/LTR layout for metafile
- `SetIcmMode` — colour management on/off
- `ScaleViewportExtEx` / `ScaleWindowExtEx` — scale window/viewport

## Outcomes

- All registered in `HANDLERS` with proper handlers.
- `DeviceContext` gains `brush_origin`, `layout`, `icm_mode` accessors.

## Files

- `lib/emfsvg/device_context.rb`
- `lib/emfsvg/visitors/emr_visitor.rb`

## Verification

- Per-record specs; state correctly tracked.
