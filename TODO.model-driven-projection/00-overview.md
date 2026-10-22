# Issue #23 — Own the EMF→SVG projection

## Problem

`emfsvg` already parses through `Emf.parse` and renders an `Emf::Model::Metafile`, so the architectural handoff described by [claricle/emfsvg#23](https://github.com/claricle/emfsvg/issues/23) is substantially present. The remaining work is to pin that Ruby model boundary and its reference inputs, make all 1,048 examples in the existing suite pass on the model-driven path, replace partial or live-reference comparisons with explicit hermetic byte contracts, and make corrupted input safe under measured time and memory limits.

The 1,048 examples are the whole suite on main at `101356d`, not 1,048 distinct corpus files. Its byte-comparison groups are `spec/golden_spec.rb` (208 examples), `spec/round_trip_golden_spec.rb` (209 examples), and `spec/compat_with_libemf2svg_spec.rb` (426 examples). The C implementation remains a reference and provenance tool only, never a runtime dependency.

## Scope

- Keep `Emf.parse`, `Emf::Model`, and `record.wire` as the production model boundary; issue #23 does not add a direct Rust binding.
- Pin an external `claricle/emf` corpus checkout and fail closed when its revision, inputs, expected outputs, or suite counts differ from the manifest.
- Treat [claricle/emf#15](https://github.com/claricle/emf/issues/15) as an external gate only for what its published issue promises: a model-compatible native parser, Ruby fallback, fixture/model parity, corrupt-input crash resistance, round-trip compatibility, and its performance target. Record the exact landed revision and pin the downstream runtime independently of the corpus checkout.
- Require separate `claricle/emf` issues for the structured diagnostic and typed resource-limit consumer contracts described in card 02 unless the landed #15 revision demonstrably supplies them. Those upstream changes and their effort are outside issue #23.
- Make the complete 1,048-example suite green on the model-driven path and give every example in the 208/209/426 comparison groups an explicit byte or artifact-integrity oracle without silent skips or pending comparisons.
- Pin libemf2svg source/build provenance for explicit reference audits and atomic golden regeneration only.
- Render every corrupted file that tolerant parsing can read and emit one warning listing skipped records; raise `Emfsvg::ParseError` only when the file is unreadable, such as when it has no valid header.
- Inventory the real parser and renderer guards, close pre-allocation gaps, and derive enforceable per-file time and memory bounds from bounded measurements so a regression cannot repeat the observed 15–17 GB runs.
- Sequence overlapping renderer and formatting work around draft [claricle/emfsvg#24](https://github.com/claricle/emfsvg/pull/24).
- Align compatibility documentation and release evidence with the enforced behavior.

## Exclusions

- Any implementation or qualification inside `claricle/emf`, including #15 and the separate diagnostic/resource-contract prerequisites. This plan defines only the observable contracts that `emfsvg` consumes and the evidence required before pinning an upstream revision or release.
- Adding or packaging a direct Rust consumer API in `emfsvg`.
- Vendoring the approximately 37 MB external EMF corpus.
- Adding broad support for previously unsupported records unless a failing accepted example proves it is required.
- Reintroducing libemf2svg as a runtime or packaged dependency.
- Running live C conversion in the ordinary suite; it remains an explicit audit/regeneration operation.
- Hardening the standalone `Emfsvg::DibDecoder`, which has no production EMF-to-SVG call site. Open a follow-up only if a pinned corrupt fixture demonstrates a reachable production path.

## Intended end state

- Production conversion remains Ruby `Emf.parse` → `Emf::Model` façade → `Emfsvg::Renderer`, with `record.wire` available and no runtime C dependency.
- The installed `emf` runtime is pinned to a revision that has landed #15 and satisfies the separately tracked diagnostic/resource consumer contracts. Final qualification uses a released version containing that revision; its package version/checksum and source revision are recorded separately from the corpus revision. `emfsvg` preserves the typed upstream failure as `Emfsvg::ResourceLimitError`.
- CI materializes a revision-pinned external corpus and proves that all 1,048 baseline examples, plus the new contract coverage added by this work, pass together.
- The 208 golden cases compare Ruby output to C-generated goldens; the 209 round-trip cases comprise 208 byte-exact round trips plus one exact inventory digest; and the historical 426 compatibility cases comprise 208 Ruby-to-C-golden comparisons, 208 C-golden provenance/digest checks, nine fixed-sample Ruby-to-C-golden comparisons, and one exact aggregate digest.
- Recoverable corrupted files return bounded SVG and one stable warning that identifies every skipped record; unreadable files raise only `Emfsvg::ParseError`.
- Each corrupted case runs in isolation under explicit wall-clock and memory ceilings, with timeout, memory exhaustion, signal, or untyped exceptions reported by basename.
- Golden regeneration is reviewable and atomic; a failed conversion cannot partially refresh the baseline.
- Documentation states the same parity, warning, and error guarantees that tests enforce.

## Dependencies and ordering

1. Card 01 can begin immediately by recording the known suite groups and separate corpus, runtime-package, native-library, and reference provenance and adding a companion normal CI job that materializes the pinned corpus in the same job that runs parity tests.
2. Wait for #15 to land at a recorded full revision and verify only its published model/parser acceptance. Inspect that revision for the card 02 diagnostic and resource consumer contracts; if either is absent, track it in a separate upstream issue and wait for a revision that passes the named conformance checks. Card 02 may use that full SHA as a temporary Bundler Git pin for integration. Final qualification waits for a containing `emf` release, tightens `emfsvg.gemspec` to that minimum with the existing `< 0.2` compatibility ceiling, refreshes `Gemfile.lock`, and verifies the installed package independently of the corpus checkout.
3. Land or rebase draft PR #24 before overlapping renderer or format-helper changes, then preserve its hot-path improvements behind the same byte-exact gates.
4. Card 03 may proceed once card 01 has established the shared manifest and an `emf` runtime satisfying #15 is pinned. Card 04 additionally waits for card 02 and the separate diagnostic and resource-limit contract gates, and must not calibrate or claim bounded conversion against an earlier package or source revision. Cards 03 and 04 may run in parallel once both are unblocked.
5. Card 05 qualifies the integrated post-PR-#24 branch. Any parity failure must be repaired in the responsible parser, model, or renderer path rather than regenerated away.

## Effort

| Card | Work item | Estimate |
| --- | --- | ---: |
| 01 | Pin transition inputs and reference provenance | 2–3 engineer-days |
| 02 | Define the model-projection contract | 2–4 engineer-days |
| 03 | Enforce byte-exact parity and reviewed regeneration | 3–5 engineer-days |
| 04 | Project the corrupted corpus safely | 3–6 engineer-days |
| 05 | Qualify the integrated transition and align documentation | 1–2 engineer-days |
| **Total** |  | **11–20 engineer-days** |

The range covers only `emfsvg` work: defining the downstream boundary, assigning the per-example oracles, adding an implementable companion CI job, measuring and enforcing per-platform resource limits, and adding warning/resource assertions. It excludes implementation effort and elapsed waiting for #15, the separate upstream diagnostic/resource-contract issues, an upstream release, the pinned native artifact, and PR #24. Contingency is **0 engineer-days** separately because the card ranges already include identified downstream uncertainty. Cards 03 and 04 may overlap in elapsed time after their shared prerequisites, but their engineering effort remains additive. Standalone DIB hardening and broad new record support are also omitted.

## Technical decisions

1. The model boundary is the existing Ruby façade: `Emf.parse`, `Emf::Model`, and `record.wire`. Direct Rust consumption is outside this issue.
2. The 1,048-example acceptance target is the complete baseline suite on main at `101356d`, not a forever-fixed suite size; the finished whole suite must be green after adding new coverage. The three comparison groups retain exactly 208, 209, and 426 examples, with the per-example oracle roles specified in card 03 rather than treating all 843 examples as distinct conversions.
3. CI uses a revision-pinned external `claricle/emf` checkout for corpus inputs, but Bundler loads a separately pinned `emf` runtime package. The corpus is not vendored, and its checkout revision is never treated as proof of the loaded gem code.
4. Tolerantly parsed files render and return a warning listing skipped records. Only unreadable files raise `Emfsvg::ParseError`; crashes, hangs, memory blow-ups, and backend-specific exceptions are failures.
5. libemf2svg is used only to establish reference provenance, audit committed artifacts, and regenerate them intentionally. It is not loaded or packaged at runtime.
6. Draft PR #24 is in flight and must be landed or rebased before resolving overlapping conversion-hot-path work.
7. #15 is not the owner of requirements absent from its published issue. Structured diagnostic fields and typed cross-backend resource failures are separate external consumer-contract gates unless they are present in the landed #15 revision; issue #23 neither chooses their internal implementation nor counts their effort.
8. The required diagnostic contract exposes each affected record's zero-based physical index, integer code, canonical type, byte offset, and disposition (`skipped` or `preserved_raw`) identically under `ruby`, `native`, and native-selected `auto`. `emfsvg` emits its one-line warning from `skipped` entries only.
9. The in-flight upstream selector defaults `EMF_BACKEND` to `auto`. Qualification provisions the pinned native library so `auto` demonstrably selects native, while conformance is also exercised explicitly under `ruby` and `native`; a missing native artifact is a failed precondition, not evidence from Ruby fallback.
10. Final downstream qualification requires a released `emf` version containing the recorded prerequisite revision. A full-SHA Git source in `Gemfile`/`Gemfile.lock` is permitted only as a temporary integration pin before that release; it is not the consumer-facing dependency guarantee.

## Decisions still needed

None. The model boundary, full-suite and comparison counts, corrupted-input behavior, external-corpus policy, libemf2svg role, and PR #24 sequencing are settled; unavailable upstream and reference revisions are evidence gaps and prerequisites, not owner choices.
