# Security policy

## Scope and support

Security fixes target the current development branch and the next release. The
current stable release, 0.4.1, includes finite directed arcs and bounded diagnostics, in addition to checked creation/editing and solver
work budgets. Older versions do not have a separate maintenance branch.
There is no guaranteed response or patch deadline.

The library runs in its host application, with no networking, authentication,
file parsing or sandbox. Bounded geometry and solver work reduce resource abuse;
they do not impose a wall-clock deadline or isolate hostile callers. Applications
handling untrusted jobs should use checked builders and setters, restrict their own request
sizes, and enforce process/worker time and memory limits.

## Reporting

Use GitHub's private [Report a vulnerability](https://github.com/mik1e80/moonbit-cad-sketch/security/advisories/new)
form. Include the affected version/commit, backend/toolchain, minimal reproducer,
expected and actual behavior, and impact. Do not attach credentials, private CAD
files or personal information. If the private form is unavailable, open an issue
requesting a private reporting channel without publishing exploit details.

Ordinary correctness issues without security impact can be reported in public
issues. Please keep exploitable details private until maintainers have evaluated
the report and coordinated a fix and disclosure. Confirmed fixes will identify
affected/fixed versions in the changelog and, when appropriate, a GitHub security
advisory. Published package versions are never overwritten.

This policy is a reporting process, not a claim of independent security audit or
engineering certification. See [limitations](docs/LIMITATIONS.md).


## Arc, lifecycle and diagnostic boundaries

Checked arc builders/editors reject invalid definitions; intrinsic equal-radius equations are mandatory. Finite-arc membership is piecewise smooth and initial-value sensitive. Geometry deletion is reference checked, including disabled constraints, with stable non-reused IDs. Diagnostics copy state and enforce subset/rank/QR budgets; they are not proofs of infeasibility or wall-clock isolation. Hosts must still isolate untrusted work and synchronize mutable Sketch access. See [geometry specifications](docs/GEOMETRY_SPEC.md) and [diagnostic bounds](docs/DIAGNOSTIC_DESIGN.md). The [maintenance evidence](docs/MAINTENANCE.md) records the scope of checked-edit, snapshot and budget verification.
