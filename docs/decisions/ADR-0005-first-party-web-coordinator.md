# ADR-0005: First-party web coordinator with public Esplora fallback

- Status: Accepted for pre-alpha implementation
- Date: 2026-07-31

## Context

The offline signer currently depends on a separate wallet application to watch
addresses, select coins, construct PSBTs, scan the signed result, finalize, and
broadcast. That makes the safest path difficult for a first-time user and adds
an application-level dependency the project cannot control.

Adding networking to `ColdSignerApp` would weaken the clearest security boundary
in the repository. Building a second native iOS app would add App Store
distribution and review overhead without improving the online coordinator's
key security: it holds only public wallet data.

Running a Bitcoin node and Esplora server provides better sovereignty and
privacy but is not a reasonable precondition for the first release.

## Decision

- Keep `ColdSignerApp`, `ColdSignerCore`, and `ColdSignerTransport` completely
  offline and covered by the existing first-party network guard.
- Add a separately built installable web app under `Coordinator/`.
- Import only `[fingerprint/84h/coinh/0h]xpub|tpub` or an equivalent public
  descriptor. Derive receive and change addresses locally in the browser.
- Store only the public account export in browser local storage. Do not accept
  mnemonics, seeds, xprvs, or private keys.
- Support one BIP84 recipient, PSBT v0, `SIGHASH_ALL`, RBF, witness UTXO data,
  input BIP32 ownership claims, and authenticated change metadata.
- Use uppercase hex BBQr `P` for the first-party optical path because it is
  already implemented and bounded in the offline signer.
- Route chain access through a same-origin Cloudflare Worker. Use
  mempool.space as primary and Blockstream Esplora as fallback for timeouts,
  HTTP 429, and 5xx responses.
- Disable Worker observability, do not cache address/API responses, and never
  place an xpub or descriptor in a request.
- Before a UTXO can enter a PSBT, fetch its complete previous transaction from
  the provider that did not supply the UTXO list, recompute the txid, and match
  the output index, value, and script. Fail closed on disagreement.
- After scanning a signed PSBT, require an exact unsigned-transaction match and
  exact fee match before finalization. On an ambiguous broadcast timeout, query
  the expected txid on the fallback before broadcasting again.

## Consequences

The normal user installs no third-party wallet software and can add the PWA to
an iPhone home screen. Static assets and the Worker can run within Cloudflare's
free or low-cost tier; GitHub remains the source and CI host.

Public Esplora providers can correlate derived address queries by timing and
Worker egress. The architecture hides the user's IP from providers but does not
provide strong wallet-query privacy. A self-hosted Esplora endpoint remains the
recommended future privacy mode.

The Coordinator becomes security-sensitive transaction software and requires
independent review, funded testnet round trips, dependency provenance review,
and explicit mainnet release gates. It is not evidence that the offline signer
itself has gained a network path.
