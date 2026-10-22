# 05 — Qualify the integrated transition and align documentation

## Context

Draft PR #24 is based on the same `origin/main` commit as this plan and changes conversion hot paths in `renderer.rb` and `format_helpers.rb`, including a `record.wire`-based cache and byte-sensitive formatting optimizations. Qualification must run after landing or rebasing #24 so the final evidence covers its overlapping behavior.

## Work

- Land or rebase the issue #23 implementation with PR #24 and resolve renderer/format-helper overlap by preserving its intended optimizations, the pinned Ruby model contract, and byte-identical output.
- Make the revision-pinned external corpus, landed #15 revision, separate diagnostic/resource contract revisions, released `emf` package/source mapping, native library artifact, exact manifest counts, all three byte-comparison groups, and bounded corrupted-corpus suite required in CI with no developer-specific setup. Run the release gate under `EMF_BACKEND=auto` with the pinned library available and assert both the loaded package provenance and native selection.
- Run the complete suite and fail unless all 1,048 baseline examples plus new contract coverage pass, with no comparison skip or pending result.
- Keep a live pinned-libemf2svg audit as a separate explicit command for provenance verification and intentional regeneration; ordinary CI consumes committed artifacts and never loads C at runtime.
- Verify the enumerated comparison/regeneration entry points: `spec/support/emfsvg_compat.rb` is the sole explicit C resolver; `spec/fidelity_regression_spec.rb` is converted to an opt-in live-reference audit; `scripts/run_emf_svg_compare.rb` is an opt-in live-reference audit; and `scripts/regenerate_golden.rb` uses the shared corpus/C resolvers and atomic staging. The ordinary compatibility spec remains committed-artifact-only.
- Scan `.github`, `lib`, `spec`, `scripts`, `README.adoc`, and `docs` for developer-specific absolute paths or sibling `../emf`/`../libemf2svg` assumptions, and route every hit through the manifest/corpus or live-C resolver.
- Align the existing `README.adoc`, `spec/fixtures/README.adoc`, `docs/compatibility_matrix.adoc`, and `CHANGELOG.adoc` release notes on the Ruby model boundary, exact comparison composition, corrupted-input warning/error behavior, measured resource ceilings, runtime-versus-corpus provenance, reference provenance, and external corpus setup.
- Build the gem and add proposed `scripts/check_runtime_package.rb` to open the built archive and check its complete file list and runtime dependency metadata, confirming that neither libemf2svg, C-reference helpers, nor the external corpus checkout is shipped.
- Record the exact full-suite result, three comparison-group results, corrupt-case result, #15 and separate upstream contract revisions, released `emf` package version/checksum/containing source revision, corpus revision, pinned C reference revision, and any intentionally reviewed output changes in a proposed `docs/issue_23_release_evidence.adoc` handoff.

## Done when

- The post-PR-#24 integrated branch passes the whole suite, including all 1,048 baseline examples and new contract coverage, with every example in the three comparison groups satisfying its card 03 byte or artifact-integrity oracle.
- The comparison groups report exactly 208 golden, 209 round-trip golden, and 426 compatibility examples with no skipped or pending comparisons.
- Every corrupted fixture meets its warning/error contract under native-selected `EMF_BACKEND=auto` within the calibrated platform limits, and CI fails if the native parser artifact or configured enforcement backend is unavailable.
- CI reproduces the required gates from a clean checkout using the pinned external corpus.
- CI proves that `emfsvg.gemspec` and `Gemfile.lock` resolve the first qualifying released `emf` package containing the recorded issue #15 revision and separate diagnostic/resource-contract revisions, and that the loaded package/source mapping is independent of the external corpus checkout.
- Live reference audit and `--check` regeneration succeed against the pinned C build without changing committed artifacts.
- Documentation describes the enforced guarantees, and neither the packaged gem nor runtime dependency graph contains libemf2svg or the corpus checkout.

```sh
EMF_BACKEND=auto EMF_NATIVE_LIBRARY="$EMF_NATIVE_LIBRARY" bundle exec rspec
EMF_BACKEND=auto EMF_NATIVE_LIBRARY="$EMF_NATIVE_LIBRARY" bundle exec rspec spec/parity_manifest_spec.rb spec/golden_spec.rb spec/round_trip_golden_spec.rb spec/compat_with_libemf2svg_spec.rb spec/corrupted_resilience_spec.rb spec/emfsvg/format_helpers_spec.rb
EMF2SVG_REF_PATH=/path/to/pinned/emf2svg_ref EMF2SVG_REF_LIB_DIR=/path/to/pinned/lib bundle exec ruby scripts/regenerate_golden.rb --check
bundle exec rubocop
mkdir -p tmp
gem build emfsvg.gemspec --output tmp/emfsvg.gem
bundle exec ruby scripts/check_runtime_package.rb tmp/emfsvg.gem
git diff --check origin/main...HEAD
if rg -n '/Users/|/home/|\.\./(emf|libemf2svg)' .github lib spec scripts README.adoc docs; then exit 1; else test $? -eq 1; fi
```

## Status
State: todo
PR: none
