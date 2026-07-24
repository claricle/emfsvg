# TODO 01 — Register missing state-only handlers

**Priority:** P0
**Depends on:** —

## Context

Several state-only records are already implemented as visitor methods
but are NOT registered in the `HANDLERS` hash, so they never fire.
Quick wins: each is one line in `HANDLERS`.

## Outcomes

- `SetBrushOrgEx`, `SetMetArgn`, `OffsetClipRgn` registered and
  updating the device context.
- `ScaleViewportExtEx`, `ScaleWindowExtEx`, `SetMapperFlags`,
  `SetStretchBltMode`, `SetRop2`, `SetLayout`, `SetIcmMode`,
  `SetArcDirection`, `SetMiterLimit` (some already registered).
- No visual output for these; just state tracking.

## Files

- `lib/emfsvg/visitors/emr_visitor.rb` — extend `HANDLERS` map

## Verification

- Per-record spec for each: parse EMF with the record, render, verify
  no exception.
- Compat matrix: percent handled rises.
