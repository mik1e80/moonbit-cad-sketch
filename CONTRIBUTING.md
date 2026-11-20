# Contributing

Open an issue for significant API or mathematical changes before implementation.
Branch from main, use focused commits and merge through a PR with reproducible checks. Follow the [maintenance checklist](docs/MAINTENANCE_REVIEW.md) to record evidence for changes that affect public behavior, provenance or compatibility.
Keep changes focused and preserve failed-solve atomicity, sketch-local handles,
stable constraint IDs, and the resource/input limits.

For a new constraint, document its mathematical definition, directed/signed
semantics, units, degeneracies and tolerance interpretation in
[CONSTRAINTS](docs/CONSTRAINTS.md). Add analytic geometry checks, finite-difference
checks for new residual derivatives, invalid/foreign input tests, and a public
usage example. Bug fixes need a regression test showing the failure.

Run `moon fmt --check`, `moon check --target all --deny-warn`, the directly affected
test files and relevant examples. Run `moon info` and review interface changes.
The default CI runs a focused smoke suite on four backends. Larger generated
experiments and complete regression are manual opt-ins; do not replace historical
measurements with unexecuted or estimated results. Describe exactly what was run
in the pull request. Changes to resource or solver limits should include boundary
and budget-exhaustion cases.

Do not copy third-party solver code, tests or data without compatible permission
and retained attribution. Update [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md) for
new dependencies, tools or reused material. Contributions intentionally submitted
for inclusion are provided under Apache-2.0, according to section 5 of
[LICENSE](LICENSE), unless a separate written agreement states otherwise. Submit
only material you are authorized to license. No separate contributor agreement
is required by this document.

For reproducible integration feedback, use the bug or integration form in [GitHub Issues](https://github.com/mik1e80/moonbit-cad-sketch/issues/new/choose) and see the evidence checklist in
[Maintenance and application validation](docs/MAINTENANCE.md). Do not include private
CAD files or report self-authored consumer tests as third-party adoption.

Report exploitable security issues through [SECURITY](SECURITY.md), rather than
posting details in a public pull request or issue.


## Generated geometry and reference material

For new fixtures, follow [MODEL_DATA_POLICY](docs/MODEL_DATA_POLICY.md): record source, redistribution rights, license, revision and hashes before adding external data. Self-authored analytic configurations are versioned separately from historical measurements. Never relabel GPL code/data, invent external adoption, or report planned test counts as measurements. Keep README, public signatures, boundaries and real release evidence synchronized.
