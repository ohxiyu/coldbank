# Contributing

ColdSigner is security-sensitive software. Small, reviewable changes are preferred.

## Before opening a pull request

1. Start from an issue with a defined acceptance criterion.
2. Keep cryptographic, transport, and UI changes in separate commits where possible.
3. Add tests for parsers, transaction policy, and compatibility behavior.
4. Run `make check` and the relevant simulator tests.
5. Do not add networking, telemetry, analytics, remote fonts, crash uploaders, or dynamic code loading.

Changes to seed handling, signing policy, dependency versions, supported script types, PSBT interpretation, or QR payload formats require an Architecture Decision Record under `docs/decisions/`.

## Pull request checklist

- No secret, mnemonic, xprv, PSBT, address, or transaction data is logged.
- No sensitive value is copied to the system clipboard.
- Error messages fail closed and do not silently downgrade validation.
- New inputs have size and complexity limits.
- Tests include malformed and adversarial inputs, not only happy paths.
- User-visible security claims match `docs/SECURITY-BASELINE.md`.

Security reports must follow `SECURITY.md`, not public issues.
