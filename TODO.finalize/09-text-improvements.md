# TODO 09 — Text improvements: Dx array, alignment, RTL, glyph indices

**Priority:** P1
**Depends on:** —

## Context

Current `ExtTextOutA`/`ExtTextOutW` rendering is MVP:

- Decodes the string
- Emits one `<text>` element
- Uses WmfRect16 as the origin
- Ignores `fOptions`, `offDx`, alignment

Missing:

- **Dx array**: per-character x-offsets from the EMR's `offDx`. Without
  this, character spacing is the renderer's default, which differs
  from the original.
- **Text alignment**: `TA_LEFT/RIGHT/CENTER` horizontal, `TA_TOP/
  BOTTOM/BASELINE` vertical — affects where the anchor sits.
- **RTL / `TA_RTLREADING`**: needs `direction="rtl"` on `<text>`.
- **ETO_GLYPH_INDEX flag (0x0010)**: string is glyph indices, not
  Unicode codepoints. Needs a font→glyph map; libemf2svg shells out
  to fontconfig/freetype via `emf2svg_gen_font_index`. For now, we
  emit the raw indices as text (lossy but doesn't crash).

## Outcomes

- Dx array honoured: emit `<tspan x="...">` per character, or
  per-character absolute positioning.
- Text alignment: `text-anchor` and `dominant-baseline` attrs.
- RTL: `direction="rtl"` when `TA_RTLREADING` set.
- ETO_GLYPH_INDEX: documented limitation; emit raw indices.

## Files

- `lib/emfsvg/visitors/emr_visitor.rb` — `emit_ext_text` rewrite

## Verification

- Per-record spec comparing against libemf2svg's output for a text-
  heavy fixture.

## Notes

Full glyph-index support requires a font rasteriser. The pure-Ruby
equivalent of libemf2svg's font mapping is out of scope.
