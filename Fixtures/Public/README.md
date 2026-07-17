# Public interoperability fixtures

Only deterministic, publicly documented test vectors and testnet/signet transactions belong here. Never commit a mnemonic used outside a published standard, a mainnet private key, a personally linked address, or an unpublished transaction.

Each fixture directory must contain:

- `manifest.json` matching `manifest.schema.json`;
- `unsigned.psbt` and expected `signed.psbt` where applicable;
- `decoded.json` with normalized semantic expectations;
- deterministic UR parts when the test needs transport equivalence;
- reproduction steps and upstream coordinator version.

The first fixture set will be added with the Sparrow interoperability milestone.
