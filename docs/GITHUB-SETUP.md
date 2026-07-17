# GitHub repository setup

The local repository is initialized on `main` with the open-source baseline. Publishing is intentionally a separate step because repository ownership and visibility must be chosen by the maintainer.

## Recommended repository metadata

| Field | Recommendation |
|---|---|
| Name | `coldsigner` |
| Description | Open-source air-gapped Bitcoin signer for spare iPhones |
| Initial visibility | Private during pre-alpha; Public at testnet alpha |
| License | MIT |
| Topics | `bitcoin`, `psbt`, `bc-ur`, `airgap`, `swift`, `swiftui`, `ios`, `self-custody` |
| Features | Issues on; Projects on; Wiki off; Discussions on when public |

Before public launch, replace the interim security-contact flow in `SECURITY.md` with a private email or GitHub private vulnerability reporting.

## Main branch ruleset

Apply to `main`:

- require pull requests;
- require two approvals for `Security-critical`, one otherwise;
- dismiss stale approvals when code changes;
- require conversation resolution;
- require `repository-checks` and `ios-build` status checks;
- block force pushes and deletion;
- require signed commits for release tags at minimum;
- allow no direct maintainer bypass for signing-policy changes.

Enable secret scanning, push protection, Dependabot alerts, private vulnerability reporting, and code scanning when available. GitHub Actions default token permissions should remain read-only.

## Labels

Create these labels to match `docs/DEVELOPMENT-PLAN.md`:

- priority: `P0`, `P1`, `P2`
- area: `product`, `ui`, `key-lifecycle`, `bitcoin`, `qr`, `security`, `interop`, `release`
- risk: `security-critical`, `compatibility-critical`
- workflow: `ready`, `blocked`, `needs-review`, `needs-fixture`
- type: `bug`, `enhancement`, `documentation`, `research`, `upstream`

## Milestones and Project

Create milestones `M0 Repository baseline` through `M5 Testnet alpha` from the development plan. Create one GitHub Project with the fields and statuses defined there. Add each `CS-*` item as an issue only when it has an owner and acceptance criteria; do not bulk-create an unmaintainable issue dump.

## Release settings

- Use SemVer tags beginning with `v0.1.0-alpha.1`.
- Protect release environments and require approval.
- Publish source archive, dependency/SBOM record, build instructions, commit hash, and artifact SHA-256.
- Mark every pre-audit release: `Testnet only — do not use with real funds`.
- Do not publish an App Store/TestFlight link until distribution threat assumptions are documented.

## Publish commands

After choosing the GitHub owner and visibility, install/authenticate GitHub CLI or create the repository in the GitHub UI. Example only:

```bash
git remote add origin git@github.com:OWNER/coldsigner.git
git push -u origin main
```

Do not run these commands until `OWNER`, repository visibility, security contact, and public naming are confirmed.
