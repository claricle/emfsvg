# Progress and handoff

## Current state

- Planning base is `origin/main` at `101356dcf673841fda0693076131bca7a0f34948`.
- Production is already model-driven: `Emf.parse` returns the `Emf::Model` consumed by `Emfsvg::Renderer`, `record.wire` is part of that seam, and libemf2svg is not a gem runtime dependency.
- A dry run on main reports 1,048 examples in the whole suite. The byte-comparison groups are 208 golden, 209 round-trip golden, and 426 compatibility examples. Card 03 assigns a hermetic byte or artifact-integrity oracle to every settled example.
- The external corpus exposes 21 corrupted inputs but no end-to-end projection spec. Prior unbounded attempts consumed approximately 15–17 GB. The settled contract is bounded SVG plus one exact skipped-record warning for recoverable files and `Emfsvg::ParseError` only for unreadable files.
- The published [claricle/emf#15](https://github.com/claricle/emf/issues/15) preserves `Emf.parse`/the model while introducing the native parser and Ruby fallback. Its stated acceptance covers model parity on named fixtures, corrupt-input parsing without crashing within 60 seconds, round-trip compatibility, and a performance target. It does not promise record limits, structured diagnostics, typed resource failures, native status mapping, or a package release.
- No linked #15 PR or landed revision has been established. The issue was available for inspection, but the latest PR lookup could not reach the GitHub API; do not choose a runtime pin until the linked work and exact revision can be verified.
- The currently inspected upstream model exposes `Metafile#errors` without record index or disposition. Some entries correspond to dropped records and others to records preserved as `Raw`; valid unknown records may also be `Raw` without an error. Card 02 therefore requires a separate upstream structured-diagnostic contract unless the landed #15 revision demonstrably adds it.
- The currently inspected upstream runtime does not expose the cross-backend typed resource contract consumed by card 02. That contract belongs in a separate upstream issue unless the landed #15 revision demonstrably adds it; its implementation and effort are outside this issue.
- The downstream runtime is not pinned to any of those prerequisites: `emfsvg.gemspec` currently allows `emf ~> 0.1`, and `Gemfile.lock` resolves RubyGems package `emf 0.1.2`. `EMF_FIXTURE_ROOT` changes corpus inputs only. Card 02 permits an exact Git revision for pre-release integration, but final qualification requires a released package containing the recorded prerequisite revisions.
- `Emfsvg::ResourceLimitError` does not exist. Card 02 explicitly proposes its definition in `lib/emfsvg/error.rb`, loading and translation in `lib/emfsvg.rb`, and focused hierarchy/metadata/cause checks in `spec/emfsvg_spec.rb`.
- Draft PR #24, head `8b5b64b059547101bb3a8f70636615b28524fc98`, shares this plan's merge base and overlaps conversion hot paths in `renderer.rb` and `format_helpers.rb`.
- `.github/workflows/rake.yml` defines `rake` as a reusable-workflow call, so it cannot accept local checkout steps. Card 01 adds a separate normal `model-parity` job that materializes and tests the corpus in one environment.
- The actual documentation targets are `README.adoc`, `spec/fixtures/README.adoc`, `docs/compatibility_matrix.adoc`, and `CHANGELOG.adoc`.
- Machine defaults occur in `spec/support/emfsvg_compat.rb`, `spec/fidelity_regression_spec.rb`, and `scripts/run_emf_svg_compare.rb`; `scripts/regenerate_golden.rb` also assumes sibling inputs. Cards 01 and 05 explicitly assign all four entry points to the shared corpus/live-C resolver design.
- Resource limits are not uniformly present: the inspected upstream parser has input and variable-array checks but no stable consumer contract for the needed resource outcome, while the renderer checks `MAX_OUTPUT_BYTES` only after building the SVG. `DibDecoder` has no renderer or CLI call site and remains outside this issue.
- libemf2svg is not a Ruby gem, so `Gem.loaded_specs` cannot prove runtime isolation. Card 02 uses real conversion subprocesses with a forbidden resolver sentinel, `$LOADED_FEATURES`, and platform-supported shared-library inspection; Card 05 separately inspects the built gem archive and runtime dependencies.

## Next executable action

Start card 01 by adding the per-basename source/C-golden/round-trip manifest with distinct corpus, runtime-package, upstream-contract, native-library, and C-reference provenance, then add the fail-closed corpus resolver and normal companion CI job. In parallel, the upstream owners must finish #15 and, if its landed revision lacks either required consumer contract, track structured diagnostics and typed cross-backend resource failures in separate `claricle/emf` issues. Once exact landed revisions exist, use a full-SHA Git pin for downstream integration and run the card 02 conformance commands. Do not begin card 04 calibration until those gates pass. Final qualification waits for a containing `emf` release, and renderer/format-helper work sequences after PR #24 lands or is rebased.

## Dependencies

- Card 02 waits for #15 to land at a verified revision satisfying its published acceptance through `Emf.parse`, `Emf::Model`, and `record.wire`; #15 is not the owner of unstated diagnostics, limits, status mapping, or packaging work.
- If absent from that revision, a separate upstream diagnostic issue must land the proposed immutable index/code/type/offset/disposition contract and pass the same fixture under `EMF_BACKEND=ruby`, `native`, and native-selected `auto`, including the skipped-versus-preserved-`Raw` distinction.
- If absent from that revision, a separate upstream resource issue must land the typed `Emf::ResourceLimitError` consumer contract with stable `resource`, `limit`, and `actual` metadata and pass equivalent accepted/rejected inputs under all three backend selections. The internal guard and native mapping design belong to that issue, not this plan.
- Pre-release integration may pin the combined prerequisite revision by full Git SHA in `Gemfile`/`Gemfile.lock`. Final qualification waits for a released package containing it, then pins the literal minimum in `emfsvg.gemspec` and the package/checksum in `Gemfile.lock`.
- Card 04 cannot calibrate or claim bounded conversion until the runtime provenance and both conformance contracts pass independently of the corpus checkout. Its production gate must prove that `auto` selected native.
- Card 01 can define the required C provenance fields now, but the exact libemf2svg source commit and reproducible build inputs behind existing committed artifacts still need to be recovered or regenerated from a known pin.
- PR #24 remains in flight; cards touching `renderer.rb` or `format_helpers.rb` must sequence after it lands or rebase onto its final form.

## Remaining gaps

- Exact linked PR and landed revision for #15, plus separate upstream issue URLs/revisions for diagnostic and resource contracts if #15 does not supply them.
- A containing `emf` release and the downstream `emfsvg.gemspec`/`Gemfile.lock` runtime pin; no estimate in this plan includes that upstream implementation or waiting time.
- Revision-pinned external corpus provisioning and exact inventory validation.
- Explicit Ruby façade, exact warning channel, `Emfsvg::ResourceLimitError`, and public parse-error contract specs.
- Fresh-process proof that successful, unreadable, and resource-limit paths do not invoke or load libemf2svg, plus built-gem file/dependency inspection.
- The explicit 208/209/426 oracle conversion: 208 Ruby-to-C-golden; 208 round trips plus one complete inventory digest; and compatibility's 208 Ruby-to-C-golden, 208 C-artifact digest/provenance, nine fixed-sample byte comparisons, and one aggregate digest.
- Atomic, reviewable C-reference regeneration with complete provenance.
- The proposed downstream `spec/fixtures/resource_limits/emfsvg-v1.yml`, generated from pinned inputs with separate RSS, virtual-address-space, and wall-time evidence and explicit outer caps.
- Bounded, sequential resource calibration below the machine guard, followed by per-file corrupted-case isolation with Linux `RLIMIT_AS`, independent parent-enforced RSS/time ceilings, and explicitly non-authoritative macOS address-space evidence.
- Post-PR-#24 evidence that all 1,048 baseline examples plus new contract coverage pass, with consistent compatibility documentation.
