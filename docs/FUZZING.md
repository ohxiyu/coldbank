# PSBT adversarial testing

ColdSigner treats a scanned PSBT as hostile input. The strict parser therefore
lives in the dependency-light `ColdSignerPSBT` target, separate from BDK/FFI and
the signing implementation. `ColdSignerCore` re-exports the same public domain
and parser API consumed by the app; this is not a second parser.

## Invariants

For every byte string up to the v0.1 two-megabyte PSBT limit, parsing must:

- finish within the configured runner timeout;
- either return a bounded normalized structure or a `ColdSignerError`;
- never trap, read/write invalid memory, or leak a foreign error;
- reject non-canonical compact sizes, duplicate keys, unsupported fields,
  excessive maps/scripts/derivations, and trailing bytes.

The fuzzer intentionally exercises the unsigned import entry point. Signed
output validation uses the same map/transaction parser with partial signatures
enabled and remains covered by deterministic Core tests.

## Deterministic sanitizer corpus

```bash
make psbt-sanitizer
```

This runs the public C03 fixture, every truncation, three bit mutations at every
fixture byte, 4,096 deterministic pseudorandom inputs, and both payload-size
boundaries under AddressSanitizer. The command fails on any foreign error or
memory violation.

## Coverage-guided fuzzing

```bash
PSBT_FUZZ_RUNS=25000 make psbt-fuzz
```

`make psbt-fuzz` requires the Swift.org 6.3.3 toolchain and refuses version
drift. The CI job downloads the exact 6.3.3 package from `download.swift.org`,
verifies the `Swift Open Source (V9AUD2URP3)` installer signature, seeds
libFuzzer with the decoded public C03 PSBT, and uploads the evolved corpus, log,
and any reproducer artifact.

The custom toolchain is used only for the fuzz executable because the Xcode
compiler does not expose the libFuzzer sanitizer on macOS. The iOS application
continues to build and test with Xcode's bundled Swift toolchain.

Any crash artifact must become a minimized deterministic regression test before
a release can proceed. A successful run proves only the tested corpus, run
count, toolchain, and commit; it is not a proof that the parser has no defects.
