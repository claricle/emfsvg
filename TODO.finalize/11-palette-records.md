# TODO 11 — Palette records

**Priority:** P2
**Depends on:** —

## Context

Palette records manage a colour palette for 8-bit / 256-colour EMFs.
Records:

- `CreatePalette` (49)
- `SetPaletteEntries` (50)
- `ResizePalette` (51)
- `RealizePalette` (52)
- `SelectPalette` (48)

77 occurrences total. Palettes mostly affect how DIBs are decoded
(TODO 07); the palette tracking is bookkeeping.

## Outcomes

- `Emfsvg::Palette` value object (array of COLORREF).
- `Emfsvg::PaletteStack` for SaveDC/RestoreDC.
- All five records parse the wire layout and update palette state.
- Dib decoder (TODO 07) consults the active palette for 8-bit images.

## Files

- Wire classes (emf repo) — already exist as stubs
- `lib/emfsvg/palette.rb` (new)
- `lib/emfsvg/palette_stack.rb` (new)
- `lib/emfsvg/device_context.rb` — add palette state
- `lib/emfsvg/visitors/emr_visitor.rb` — handlers

## Verification

- Per-record spec; palette state tracked correctly.
