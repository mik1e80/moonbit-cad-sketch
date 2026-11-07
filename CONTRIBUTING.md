# Contributing

Open an issue for significant API or mathematical changes before implementation.
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

Report exploitable security issues through [SECURITY](SECURITY.md), rather than
posting details in a public pull request or issue.
