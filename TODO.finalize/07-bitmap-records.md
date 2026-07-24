# TODO 07 — Bitmap records: BitBlt, StretchBlt, StretchDIBits, etc.

**Priority:** P0
**Depends on:** —

## Context

Bitmap records carry raw DIB (Device-Independent Bitmap) data that
must be decoded and embedded in the SVG. The records:

- `BitBlt` (76) — block transfer
- `StretchBlt` (77) — scaled block transfer
- `StretchDIBits` (81) — DIB with stretch
- `MaskBlt` (78) — masked
- `PlgBlt` (79) — parallelogram
- `SetDIBitsToDevice` (80) — direct device write
- `AlphaBlend` (114) — alpha-channel blending
- `TransparentBlt` (116) — transparent-color blit

Total 866 occurrences in the corpus. **This is the biggest remaining
visual gap.**

## Approach

DIB data is a `BITMAPINFOHEADER` + pixel array. Decoding by
`biCompression`:

- `BI_RGB` (0) — uncompressed RGB / RGBA
- `BI_RLE8` (1) — run-length encoded, 8-bit
- `BI_RLE4` (2) — run-length encoded, 4-bit
- `BI_BITFIELDS` (3) — uncompressed with custom colour masks
- `BI_JPEG` (4) — embedded JPEG (pass-through)
- `BI_PNG` (5) — embedded PNG (pass-through)

For each:

1. Parse the header (40-byte fixed + optional colour table).
2. Decode the pixel array.
3. Re-encode as PNG.
4. Embed in SVG as `<image href="data:image/png;base64,...">`.

## Outcomes

- `Emfsvg::DibDecoder` (new class) handles BI_RGB / BI_BITFIELDS for
  16/24/32-bit depths (covers ~95% of real-world DIBs).
- BI_RLE4 / BI_RLE8 supported for legacy 4/8-bit images.
- BI_JPEG / BI_PNG: pass-through as data:image/jpeg or data:image/png.
- Pure-Ruby PNG encoder (no external dep) for the output stage.
- Each bitmap record emits an `<image>` element with the encoded data.

## Files

- `lib/emfsvg/dib_decoder.rb` (new)
- `lib/emfsvg/png_encoder.rb` (new)
- `lib/emfsvg/visitors/emr_visitor.rb` — handlers

## Verification

- Per-record spec on a fixture containing StretchDIBits.
- Visual: image appears in SVG at the right position and size.

## Notes

libemf2svg uses `libpng` for encoding; we use a pure-Ruby encoder
to stay dependency-free. Output bytes will differ between the two
encoders; the visual result is identical.
