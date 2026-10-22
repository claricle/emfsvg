# 01 — Pin transition inputs and reference provenance

## Context

The 1,048 examples are the whole suite on main at `101356d`. Its byte-comparison groups contain 208 golden, 209 round-trip golden, and 426 compatibility examples. Current specs discover inputs from a sibling `../emf` checkout and may skip missing inputs or C tooling, so a clean environment can exercise only part of the acceptance surface without failing. Reference tooling also contains machine-specific paths, while fixture documentation names libemf2svg 1.8.1 without the exact source and build inputs behind committed SVGs.

## Work

- Add proposed `spec/fixtures/parity_manifest.yml` as the single inventory of accepted inputs and references. For every basename, record the pinned external EMF source path and SHA-256, its `spec/fixtures/golden/<name>.svg` C-reference path and SHA-256, and its `spec/fixtures/emfsvg_golden/<name>.svg` round-trip path and SHA-256. Keep provenance blocks distinct: the corpus checkout revision; the loaded `emf` package version or temporary Git SHA and containing source revision; the landed #15 revision; separate diagnostic/resource consumer-contract issue URLs and landed revisions when required; the native library source revision, artifact SHA-256, and ABI; and the libemf2svg reference build. Also record the production backend (`auto` with native available), the baseline whole-suite count of 1,048 for provenance, and the three comparison-group counts and compositions of 208, 209, and 426.
- Record libemf2svg source revision/version, build recipe, wrapper options, and generation command in the manifest and fixture documentation.
- Add proposed `spec/support/parity_corpus.rb` to resolve the manifest through an explicit `EMF_FIXTURE_ROOT`, verify that the checkout is at the pinned corpus revision, and reject a missing root, duplicate basename, missing file, unexpected file, or count mismatch.
- Add proposed `spec/parity_manifest_spec.rb` to prove that the materialized corpus, committed outputs, and comparison-group counts match the manifest exactly; keep the 1,048 baseline count as historical acceptance context because new contract specs legitimately increase the suite size.
- Route the golden, round-trip golden, compatibility, corrupted-input, comparison, and regeneration paths through the same resolver instead of independent globs.
- Make `spec/support/emfsvg_compat.rb` the sole live-C resolver, require explicit `EMF2SVG_REF_PATH` and `EMF2SVG_REF_LIB_DIR`, and remove its machine defaults. Convert `spec/fidelity_regression_spec.rb` into an explicitly selected live-reference audit using that resolver, excluded from the ordinary hermetic suite. Route `scripts/run_emf_svg_compare.rb` and `scripts/regenerate_golden.rb` through the same resolver; both fail with an actionable setup error when the pinned C reference is unavailable.
- Keep `.github/workflows/rake.yml`'s existing `rake` reusable-workflow job unchanged because `uses: metanorma/ci/.github/workflows/generic-rake.yml@main` cannot be combined with local steps. Add a normal companion `model-parity` job in the same workflow with checkout/Ruby/bundle steps. Bundler must install the Card 02 dependency from `emfsvg.gemspec` and `Gemfile.lock`, while a separate checkout materializes only the corpus at the manifest's corpus revision. Verify the corpus with `git rev-parse HEAD`; verify the loaded `emf` package or temporary Git revision and its source mapping from the manifest; provision and hash-check the manifest-pinned native library; export `EMF_FIXTURE_ROOT`, `EMF_NATIVE_LIBRARY`, and `EMF_BACKEND=auto`; assert through the upstream backend-selection contract that `auto` selected native rather than fallback; and run the complete suite plus the manifest, runtime-provenance, parity, and corrupted-input gates in that job environment. During pre-release integration only, the same job may consume Card 02's full-SHA `Gemfile` Git override and must assert the checkout SHA at `bundle info --path emf`; final qualification removes that override and uses the released minimum. Do not depend on undocumented reusable-workflow inputs or vendor the approximately 37 MB corpus.
- Add proposed `spec/runtime_dependency_spec.rb` to fail if the loaded gem version/source, manifest source revision and package checksum, `Gemfile.lock` resolution, or actual selected backend disagree. The spec must demonstrate that changing `EMF_FIXTURE_ROOT` cannot change the loaded gem path or satisfy runtime provenance.
- Document how to materialize and verify the external corpus and pinned C audit tools in `spec/fixtures/README.adoc`.

## Done when

- A clean test environment passes the whole suite, including all 1,048 baseline examples and new contract coverage, and cannot silently execute a partial or zero-file comparison group.
- The manifest reports exactly 208 golden, 209 round-trip golden, and 426 compatibility examples and matches every expected basename and output.
- The normal `model-parity` CI job materializes and validates the exact pinned external `claricle/emf` revision and native library artifact in the same job environment that runs the complete suite and required focused gates under native-selected `EMF_BACKEND=auto`, without vendoring the corpus.
- That job separately proves the loaded `emf` package version/source revision and checksum from `emfsvg.gemspec`/`Gemfile.lock`; a matching corpus checkout alone cannot satisfy the runtime dependency check.
- The manifest identifies the exact libemf2svg source and build provenance behind committed reference artifacts.
- `spec/support/emfsvg_compat.rb`, the explicit live audit formerly in `spec/fidelity_regression_spec.rb`, `scripts/run_emf_svg_compare.rb`, and `scripts/regenerate_golden.rb` use the shared resolvers and contain no developer-specific or sibling-checkout defaults.

```sh
bundle exec rspec spec/parity_manifest_spec.rb
EMF_BACKEND=auto EMF_NATIVE_LIBRARY="$EMF_NATIVE_LIBRARY" bundle exec rspec spec/runtime_dependency_spec.rb
bundle exec rspec --dry-run --format progress
if rg -n '/Users/|/home/|\.\./(emf|libemf2svg)' .github lib spec scripts README.adoc docs; then exit 1; else test $? -eq 1; fi
```

## Status
State: todo
PR: none
