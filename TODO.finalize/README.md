# TODO.finalize — Roadmap to libemf2svg parity

This directory tracks the remaining work to reach full feature parity
with `libemf2svg`. Each TODO is self-contained with Context, Outcomes,
Files touched, Verification, and Done-when checklist.

## Profile-driven prioritisation

Across 915,718 records in the test corpus, the unhandled types by
frequency:

| Type | Count | % | Priority |
|---|---|---|---|
| Raw (unknown types) | 3539 | 0.39% | P0 — investigate |
| SetIcmMode | 626 | 0.07% | P2 — state only |
| ExtCreatePen | 474 | 0.05% | P0 |
| SetBrushOrgEx | 465 | 0.05% | P0 — already implemented, just register |
| ExtSelectClipRgn | 444 | 0.05% | P0 — clip |
| ScaleViewportExtEx | 390 | 0.04% | P2 — state |
| BitBlt | 350 | 0.04% | P0 — bitmap |
| StretchBlt | 332 | 0.04% | P0 — bitmap |
| SetMetArgn | 268 | 0.03% | P0 — clip |
| StretchDIBits | 184 | 0.02% | P0 — bitmap |
| SetArcDirection | 101 | 0.01% | P1 — arc |
| PolyPolygon16 | 41 | <0.01% | P0 — multi-subpath |
| GradientFill | 8 | <0.01% | P1 |

## Roadmap

| # | Title | Priority |
|---|---|---|
| [01](01-register-missing-state-handlers.md) | Register missing state-only handlers | P0 |
| [02](02-ext-create-pen.md) | ExtCreatePen — geometric pens with custom styles | P0 |
| [03](03-poly-multi-subpath.md) | PolyPolygon / PolyPolygon16 / PolyPolyline / PolyPolyline16 | P0 |
| [04](04-poly-draw.md) | PolyDraw / PolyDraw16 — mixed-segment paths | P0 |
| [05](05-arc-family.md) | Arc / ArcTo / Chord / Pie — proper parametric reconstruction | P0 |
| [06](06-clip-region-tracking.md) | SelectClipPath, ExtSelectClipRgn, SetMetArgn, IntersectClipRect | P0 |
| [07](07-bitmap-records.md) | BitBlt, StretchBlt, StretchDIBits, AlphaBlend, etc. | P0 |
| [08](08-region-ops.md) | FillRgn, FrameRgn, InvertRgn, PaintRgn | P1 |
| [09](09-text-improvements.md) | ExtTextOut Dx array, alignment, RTL, glyph indices | P1 |
| [10](10-gradient-fill.md) | GradientFill — linear and path gradients | P1 |
| [11](11-palette-records.md) | RealizePalette, SelectPalette, CreatePalette, etc. | P2 |
| [12](12-misc-state-records.md) | SetIcmMode, SetLayout, SetMapperFlags, ScaleViewportExtEx | P2 |
| [13](13-create-brush-variants.md) | CreateMonoBrush, CreateDibPatternBrushPt | P1 |
| [14](14-escape-records.md) | DrawEscape, ExtEscape, NamedEscape | P2 |
| [15](15-investigate-raw-records.md) | Identify the 3539 unknown-type Raw records | P0 |
| [16](16-update-compat-targets.md) | Tighten regression floors and update README | P0 |

## Status

After completing all TODOs, emfsvg should reach >90% byte ratio with
libemf2svg on the test corpus. The remaining gap will be:

- Bitmap rendering (different PNG encoders produce different bytes)
- Text layout (font metrics differ between FreeType and SVG renderers)
- Pathological input edge cases

These are documented as permanent gaps in `docs/compatibility_matrix.adoc`.

## Conventions

Same as the main project (see CONTRIBUTING.adoc):

- **No `require_relative`** in `lib/`. Use autoload.
- **No `double()` in specs.**
- **No `send` to private methods, no `instance_variable_set/get`,
  no `respond_to?` for type checks.**
- **No AI attribution** in any commit.
- **All changes through PRs.**

For each new handler:

1. Add to `HANDLERS` hash in `lib/emfsvg/visitors/emr_visitor.rb`.
2. Implement `visit_<type>` method.
3. Add a unit spec at `spec/per_record/<type>_spec.rb`.
4. Regenerate `spec/fixtures/emfsvg_golden/`.
5. Run compat matrix; verify ratio increased.
