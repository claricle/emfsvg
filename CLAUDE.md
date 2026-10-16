# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`emfsvg` is a pure-Ruby transformer between Microsoft Enhanced Metafile (EMF) and SVG. It replaces the GPLv2 `libemf2svg` C library (and its FFI wrapper) with a clean-room Ruby implementation. The long-term goal is bidirectional `EMF ↔ SVG`. Both directions are implemented today; the SVG→EMF side is newer and covers a smaller subset.

The gem consumes the [`emf`](https://github.com/claricle/emf) gem's domain model — `Emf.parse(bytes)` returns an `Emf::Model::Metafile`. `emfsvg` adds the rendering layer on top.

## Commands

```bash
bundle install                       # set up deps
bundle exec rspec                    # full suite (~27 examples, <0.1s)
bundle exec rspec spec/svg_builder_spec.rb       # one file
bundle exec rspec -e "converts EMF to SVG"       # by description
bundle exec rubocop                  # lint (must be clean)
bundle exec rake build               # build gem into pkg/
bundle exec ruby exe/emfsvg convert INPUT.emf OUTPUT.svg   # CLI (EMF→SVG)
bundle exec ruby exe/emfsvg to-emf INPUT.svg OUTPUT.emf    # CLI (SVG→EMF)
```

### SVG → EMF round-trip tooling

```bash
bundle exec ruby scripts/run_round_trip.rb     # 208-fixture matrix
```

The round-trip test (`spec/round_trip_golden_spec.rb`) takes each SVG
in `spec/fixtures/emfsvg_golden/`, runs `SVG → EMF → SVG`, and asserts
byte-equality. Divergent fixtures are listed in
`spec/fixtures/svg_to_emf_known_divergent.txt`.

### Golden master / libemf2svg compat tooling

The repo maintains **byte-exact parity** with `libemf2svg`. To regenerate the golden set after an intentional renderer change, the C reference must be built first at `../libemf2svg/` (see `spec/fixtures/README.adoc` for the wrapper build), then:

```bash
bundle exec ruby scripts/regenerate_golden.rb    # writes both libemf2svg + emfsvg baselines
bundle exec ruby scripts/run_compat_check.rb     # per-fixture + aggregate matrix vs libemf2svg
```

`spec/golden_spec.rb` asserts byte-exact match against `spec/fixtures/golden/*.svg` for every fixture. Drift fails. `spec/compat_with_libemf2svg_spec.rb` auto-skips if the `emf2svg_ref` binary is unavailable.

The `Emfsvg::Compat` comparison utility lives in `spec/support/emfsvg_compat.rb` (NOT shipped in the gem — moved out of `lib/` in 0.1.1). Reference paths default to `/Users/mulgogi/src/claricle/libemf2svg/emf2svg_ref` and can be overridden via `EMF2SVG_REF_PATH` / `EMF2SVG_REF_LIB_DIR` env vars.

## Architecture

EMF → SVG pipeline (top-down):

```
Emf::Model::Metafile  (from emf gem)
   ↓
Emfsvg::Renderer          orchestrator: header params, two-pass path analysis, walk records
   ↓
Emfsvg::Visitors::EmrVisitor   dispatches each wire record to a visit_* handler
   ↓
Emfsvg::SvgBuilder        byte-exact XML emitter (no indentation, raw append)
   ↓
Emfsvg::DeviceContext / ObjectTable / TransformStack / BsdRand   GDI state
```

SVG → EMF pipeline (mirror direction, new in 0.2):

```
SVG bytes
   ↓  leptris
Emfsvg::Svg::Document / Svg::Element value objects
   ↓
Emfsvg::Translation::EmfRenderer   walks tree, dispatches via HandlerRegistry
   ↓
Emfsvg::Translation::Handlers::* (per element type — OCP)
   ↓
Emf::Model::Emr::Records::WireAdapter list (built from Emf::Emr::Binary::Records::*)
   ↓
Emf::Model::Metafile → Emf.serialize → EMF bytes
```

Layers are MECE:

* `Emfsvg::Svg::*` — pure SVG parsing and domain model. No EMF knowledge.
* `Emfsvg::Translation::*` — SVG-to-EMF translation. Dispatch by SVG element class. Carries GDI state.
* `Emfsvg::DeviceContext` / `ObjectTable` / `TransformStack` — shared between both directions (direction-agnostic value objects).
* `Emf::*` — provides wire record classes + serializer.

### Dispatch model (`lib/emfsvg/visitors/emr_visitor.rb`)

The visitor subclasses `Emf::Model::Visitor` and dispatches via the `HANDLERS` hash keyed by **wire record class** (`Emf::Emr::Binary::Records::*`), not by symbol. Adding a new EMF record handler means:

1. Add `Emf::Emr::Binary::Records::Foo => :visit_foo` to `HANDLERS`.
2. Implement `def visit_foo(wire) ... end` emitting SVG via `@builder`.

Unsupported records fall through silently (logged in `--verbose` mode). The visitor reads wire fields directly (e.g. `wire.rcl_box.left`, `wire.off_bmi_src`); there is no separate domain model in emfsvg.

### Two-pass path analysis (`Renderer#build_path_analysis`)

EMF's `BeginPath..EndPath` block defers `SetWorldTransform` / `ModifyWorldTransform` records — they apply either before or after the path's drawing commands, depending on whether drawing has occurred yet. The renderer pre-scans records to build:

- `path_actions`: `{ begin_idx => :fill|:stroke|:stroke_fill|:end|:abort }`
- `path_transforms`: `{ begin_idx => { wt_before:, wt_after: } }`

Mirrors libemf2svg's `U_emf_onerec_analyse` `wtBeforeSet`/`wtAfterSet` recording on `pathStackLast`. `DRAWING_PATH_RECORDS` is the list that sets `pathDrawn=true`.

### State containers

- **`DeviceContext`** snapshots GDI drawing state (pen/brush/font/text_color/world_transform/clip…). Pushed on `TransformStack` at `SaveDC`, restored at `RestoreDC`.
- **`CoordinateState`** is a *deliberately shared* mutable struct across all dup'd `DeviceContext`s — `MapMode`, window/viewport extents and origins are NOT saved/restored by `SaveDC`/`RestoreDC` in libemf2svg. This is intentional GDI behaviour, not a bug.
- **`ObjectTable`** is 1-indexed (matches EMF handle numbering).
- **`TransformStack#restore`** does NOT pop — it returns the target snapshot and leaves the stack intact. `RestoreDC`'s arg identifies a level (not a one-shot pop), mirroring Windows GDI.
- **`BsdRand`** reproduces BSD libc `rand()` (macOS default, seed 1) by reading 5000 precomputed values from `lib/emfsvg/bsd_rand_sequence.txt`. libemf2svg uses `rand()` for clip-path IDs; without the same sequence, every subsequent ID diverges. The txt file ships in the gem (see gemspec `Dir.glob("lib/**/*.txt")`).

### Byte-exact parity invariants

Many things in this codebase look weird but exist for one reason: **the SVG output must byte-match libemf2svg's output**. The `golden_spec.rb` enforces this. Examples:

- `FormatHelpers.fmt` uses `BigDecimal("%.20f" % v).round(4, half: :even)` to replicate C `printf("%.4f")` semantics on actual IEEE-754 bits (e.g. `459.04375` is stored as `459.04374999…` and must round to `"459.0437"`, not `"459.0438"`). See `spec/emfsvg/format_helpers_spec.rb`.
- `SvgBuilder` emits `/>` with no leading space (libemf2svg uses `fprintf("/>\n")`, not `" />\n"`). One exception (`emit_path_element_closed`) uses `" />"` to mirror `endFormDraw`'s literal `fprintf(" />\n")`.
- `c_int_div` replicates C's truncation-toward-zero integer division (Ruby's `Integer#/` floors, which is off-by-one for negative operands).
- The visitor emits `style ="white-space:pre;"` (note the space before `=`) and `0.00 00` in one translate transform — these are literal typos in libemf2svg's C source that we reproduce verbatim.
- `PngEncoder.encode` and `build_image_href` append zero bytes to round base64 input up to a multiple of 3, replicating libemf2svg's `fmem` modulo-3 padding so trailing base64 is `AA`/`A=` instead of `==`.
- `DibDecoder.decode_bi_rgb` performs a *global* alpha-zero check (if every alpha byte is 0, force all to 0xFF) rather than per-pixel — matches `rgb2png`.
- `parse_logfont_face_name` replicates iconv's UTF-16LE validation quirk: invalid surrogate pairs in the unused tail of the 64-byte buffer cause iconv to return NULL, so no `font-family` attribute is emitted.
- `BitBlt` with no source bitmap is rendered as a solid-fill `<path>` (NOT an `<image>`).
- Mono-pattern brushes override the DIB palette with the device context's text/bk colors at decode time.

When making changes in `emr_visitor.rb`, `svg_builder.rb`, `format_helpers.rb`, `dib_decoder.rb`, or `png_encoder.rb`, **look for the matching quirk comment** — it usually encodes a libemf2svg behaviour you must preserve.

### `fix_broken_y` (Sparx/Wine Y-repair)

EMFs produced by Sparx Enterprise Architect under Wine have only the Y anchor negated. Detection: `bounds.top * bounds.bottom < 0`. The per-coordinate repair lives in `Renderer#compute_header_params` and the visitor. The buggy-header code path emits the literal `translate(0.0000, 0.00 00)` (typo reproduced from C).

## Constraints (project-specific)

These are absolute. PRs that violate them will be rejected. (See `CONTRIBUTING.adoc` and the global `~/.claude/CLAUDE.md` for the full list.)

- **No `require_relative` in `lib/`** and no `require` of internal paths. Use Ruby `autoload` declared in the immediate parent namespace's file (e.g. `lib/emfsvg.rb` declares `autoload :Renderer, "emfsvg/renderer"`; `lib/emfsvg/visitors.rb` declares `autoload :EmrVisitor, ...`).
- **No `double()` in specs.** Use real instances or `Struct.new` for plain data.
- **No `send` to private methods**, no `instance_variable_set`/`get`, no `respond_to?` for type checks.
- **No AI attribution** anywhere (commits, PRs, code comments, changelog).
- **Never delete source files** without explicit user approval.
- **Never commit to `main`, never push tags, never push to `main`.** All changes go through PRs.
- **Library packages have no side effects.** The gem never writes to its own installed location.

## Public API

```ruby
# EMF → SVG
Emfsvg.to_svg(metafile, namespace: nil, width: nil, height: nil, verbose: false, emf_plus: false)
Emfsvg.from_bytes(emf_bytes, **opts)
Emfsvg.from_file(path, **opts)

# SVG → EMF (new in 0.2)
Emfsvg.to_emf(svg_document)
Emfsvg.from_svg(svg_string)
Emfsvg.from_svg_file(path)
```

`Emfsvg::Options` is a frozen `Struct`; `Emfsvg::RenderError` is raised if output exceeds 500 MB (`Renderer::MAX_OUTPUT_BYTES`).

## Dependencies

- `emf` (~> 0.1) — EMF binary parser, domain model, and serializer. Source of all wire record classes and `Emf.serialize`.
- `leptris` (~> 1.9.362) — SVG parser for the SVG→EMF direction.
- `fontisan` — cmap parsing for glyph-index → Unicode mapping (`GlyphIndexMapper`).
- `libpng` (~> 1.6) — PNG encode (`PngEncoder`) and decode (`PngDecoder`) for image round-trip.
- `base64`, `bigdecimal` — stdlib.

`rexml` is a **development** dependency only (used by `spec/support/emfsvg_compat.rb`). It is NOT shipped as a runtime dep — 0.1.1 explicitly removed it.

## CI

`.github/workflows/test.yml` runs `bundle exec rspec` and `bundle exec rubocop` on Ruby 3.1–3.4 across Ubuntu and macOS. `.github/workflows/release.yml` triggers on `v*` tags — pushes the gem to rubygems.org and creates a GitHub release. (Don't push tags yourself.)

## What's not yet rendered

See `docs/compatibility_matrix.adoc` for the live gap report. As of 2026-07-24 the aggregate byte ratio vs libemf2svg is ~43% across 208 fixtures. Open work: richer text/bitmap handling, EMF+ drawing records (parsed by `emf` but not yet rendered), and the **SVG → EMF** inverse direction.
