# TODO 16 — Update compat targets and documentation

**Priority:** P0
**Depends on:** all others

## Context

After closing the gap, the regression floor in
`spec/compat_with_libemf2svg_spec.rb` should rise, and
`docs/compatibility_matrix.adoc` should reflect the new state.

## Outcomes

- `spec/compat_with_libemf2svg_spec.rb` regression floor raised from
  10% to a value reflecting the new baseline (target: 70%+).
- `docs/compatibility_matrix.adoc` updated with new ratios and the
  list of remaining gaps.
- `README.adoc` status section updated.
- `CHANGELOG.adoc` entry for the new release.

## Files

- `spec/compat_with_libemf2svg_spec.rb`
- `docs/compatibility_matrix.adoc`
- `README.adoc`
- `CHANGELOG.adoc`

## Verification

- All specs green.
- Manual review of the matrix shows the closure.
