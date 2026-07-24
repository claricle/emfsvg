# TODO.finalize — Roadmap to libemf2svg parity

## Status as of 2026-07-24

| # | Title | Status |
|---|---|---|
| 01 | Register missing state handlers | **done** |
| 02 | ExtCreatePen | **done** (parse style/width/color) |
| 03 | Poly multi-subpath | **done** |
| 04 | PolyDraw | **done** |
| 05 | Arc family | **done** |
| 06 | Clip region tracking | **done** |
| 07 | Bitmap records | **done** (BI_RGB/BI_BITFIELDS/JPEG/PNG) |
| 08 | Region ops | **done** (FillRgn/FrameRgn/InvertRgn/PaintRgn) |
| 09 | Text improvements | **done** (alignment, font sizing, decorations) |
| 10 | GradientFill | **done** (MVP — solid rects per vertex pair) |
| 11 | Palette records | **done** (state tracking only) |
| 12 | Misc state records | **done** |
| 13 | Brush variants | **partial** (stubs for CreateMonoBrush/CreateDibPatternBrushPt) |
| 14 | Escape records | **done** (no-ops) |
| 15 | Investigate Raw records | **done** (99% reduction, 3539 to 38) |
| 16 | Update compat targets | **done** (59.5% byte ratio, all 186 render) |

## Additional work completed beyond TODO.finalize

- **MapMode viewport scaling**: SetWindowExtEx/SetViewportExtEx now
  trigger a `<g transform>` for MM_ANISOTROPIC. Architectural fix
  affecting 586 fixtures.
- **DibDecoder nil guards**: prevents crashes on truncated bitmap data.
- **Handler method name consistency**: linter-mangled names corrected.
- **Base64 via pack("m0")**: avoids dependency on removed Ruby 3.4 gem.
- **class << self** for DibDecoder and PngEncoder: fixes module_function
  in class issue.

## Current compat matrix

```
fixtures=186  total_ref=57642525  total_out=34324702
byte_ratio=59.5%  avg_element_overlap=36.7%
```

## Known remaining gaps to libemf2svg full ability

1. **Brush pattern fills** — CreateMonoBrush/CreateDibPatternBrushPt
   are stubs. Hatch/pattern fills not rendered.
2. **RLE4/RLE8 DIB decoding** — uncommon compression types not decoded.
3. **Dx array** for text character spacing — not applied.
4. **ETO_GLYPH_INDEX** — requires font rasteriser (out of scope).
5. **EMF+ drawing records** — emf parses but emfsvg does not render.
6. **GradientFill** — currently solid rects, not gradient definitions.
7. **World transform group lifecycle** — open groups accumulate;
   should close/reopen on each transform change.
8. **Proper ROP2 handling** — binary raster ops ignored (SVG has no
   direct equivalent; would need SVG filter chains).

These gaps are tracked for future PRs.
