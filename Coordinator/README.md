# Coldbank Coordinator

The Coordinator is the networked half of Coldbank. It imports only a BIP84
account-level public key, derives addresses in the browser, creates PSBT v0,
exchanges PSBTs with the offline iPhone over BBQr, and broadcasts only after the
signed PSBT matches the original unsigned transaction.

The Coordinator never accepts a mnemonic, seed, xprv, or private key. It is a
separate trust domain from `ColdSignerApp`, whose source remains guarded against
first-party networking APIs.

## Supported flow

1. Scan ColdSigner `Origin xpub` (a receive descriptor is also accepted).
2. Derive and scan the first 20 receive and 20 change addresses.
3. Query UTXOs and fee estimates through the same-origin Worker.
   Every spendable UTXO is checked against the complete previous transaction
   fetched from the other provider before it can enter a PSBT.
4. Build a one-recipient BIP84 PSBT v0 with `SIGHASH_ALL`, RBF, witness UTXOs,
   input ownership paths, and an authenticated change path.
5. Display uppercase hex BBQr `P` frames for the offline signer.
6. Scan the partially signed PSBT, verify the unsigned transaction and fee,
   finalize locally, and broadcast.

Mainnet and testnet are supported. The UI remains pre-alpha and recommends
testnet until independent review and device interoperability testing are
complete.

## Local development

Requirements: Node.js 22.13 or later.

```bash
npm ci
npm run dev
```

Validation:

```bash
npm run typecheck
npm test
```

## Cloudflare deployment

The production build is a Cloudflare Worker with static assets:

```bash
npm run deploy:cloudflare
```

No provider key is required. The defaults are:

- primary: `mempool.space`
- fallback: Blockstream Esplora

The optional variables in `.env.example` can point at a paid API or self-hosted
Esplora instance without changing the browser bundle. Provider logs must remain
disabled because request paths contain Bitcoin addresses and transaction IDs.

## Privacy and failure behavior

- The browser stores only the scanned account public export in `localStorage`.
- xpubs and descriptors are never sent to the Worker or providers.
- API responses and address requests use `Cache-Control: no-store`.
- Worker observability is disabled in the generated Cloudflare configuration.
- Provider fallback occurs only after timeout, HTTP 429, or 5xx.
- Each selected UTXO's txid, output index, value, and script are verified from
  an independent provider and disagreements fail closed.
- After an ambiguous broadcast timeout, the Worker checks the expected txid on
  the fallback before attempting another broadcast.
- The service worker caches static build assets only, never `/api` responses.

Public providers can still correlate address queries by timing and Worker
egress. A self-hosted Esplora instance is the future privacy upgrade.
