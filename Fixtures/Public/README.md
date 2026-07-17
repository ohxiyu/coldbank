# Public interoperability fixtures

Only deterministic, publicly documented test vectors and testnet/signet transactions belong here. Never commit a mnemonic used outside a published standard, a mainnet private key, a personally linked address, or an unpublished transaction.

Each fixture directory must contain:

- `manifest.json` matching `manifest.schema.json`;
- `unsigned.psbt.base64` and expected `signed.psbt.base64` where applicable;
- `decoded.json` with normalized semantic expectations;
- deterministic BC-UR and/or BBQr parts when the test needs transport equivalence;
- reproduction steps and upstream coordinator version.

Base64 text is preferred over opaque binary so review, secret scanning, and cross-platform fixture loading stay deterministic. Decode only into a temporary directory for a coordinator that requires a `.psbt` file.
