# Golden master fixtures

This directory holds reference SVG output used by the spec suite to lock
in emfsvg's behavior.

## Layout

```
spec/fixtures/
  golden/             # libemf2svg's output (the C reference)
    <name>.svg
  emfsvg_golden/      # emfsvg's current output (regression baseline)
    <name>.svg
```

The corresponding EMF inputs live in the `emf` gem at
`../emf/spec/fixtures/{emf,emf-ea,simple}/*.emf`.

## Regenerating

To regenerate both golden sets (e.g., after a new libemf2svg release or
after intentionally changing emfsvg's output style):

```
# 1. Build libemf2svg at ../libemf2svg/
cd ../libemf2svg
cmake -S . -B build -DLONLY=ON
make -C build
cc -I inc -L build -lemf2svg emf2svg_ref.c -o emf2svg_ref

# 2. Regenerate the golden sets
cd ../emfsvg
bundle exec ruby scripts/regenerate_golden.rb

# 3. Inspect the diff and commit if intentional
git status spec/fixtures/
```

`scripts/regenerate_golden.rb` is the canonical regenerator. Do NOT
edit golden SVGs by hand.

## What the specs assert

- `spec/golden_spec.rb`: emfsvg's output for each fixture matches the
  bytes in `spec/fixtures/emfsvg_golden/`. Any drift fails the spec.
  To update: regenerate, review the diff, commit.

- `spec/compat_with_libemf2svg_spec.rb`: structural-equivalence checks
  against `spec/fixtures/golden/`. Catches regressions in element-type
  coverage and aggregate byte ratio.

## Why two golden sets

- `emfsvg_golden/` is a **regression baseline** — locks emfsvg's own
  behavior. Tight, byte-comparable.
- `golden/` is a **reference target** — shows what libemf2svg produces
  for the same input. Drives the structural-equivalence check and the
  compatibility matrix in `docs/compatibility_matrix.adoc`.

The two converge as emfsvg implements more handlers.
