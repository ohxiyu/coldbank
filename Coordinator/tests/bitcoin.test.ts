import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { RawTx, Transaction } from "@scure/btc-signer";
import { BBQrDecoder, encodeBBQr } from "../lib/bbqr.ts";
import { verifyCoinAgainstRawTransaction } from "../lib/chain.ts";
import { finalizeSignedPSBT, type SpendPlan } from "../lib/psbt.ts";
import {
  deriveAddress,
  formatBtc,
  parseBtcAmount,
  parsePublicAccount,
} from "../lib/wallet.ts";

const ORIGIN =
  "[73C5DA0A/84h/1h/0h]tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39yBA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M";

test("imports the ColdSigner origin xpub and derives the public fixture addresses", () => {
  const account = parsePublicAccount(ORIGIN);
  assert.equal(account.fingerprintHex, "73C5DA0A");
  assert.equal(account.network, "testnet");
  assert.equal(account.accountPathLabel, "m/84'/1'/0'");
  assert.equal(
    deriveAddress(account, 0, 0).address,
    "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl",
  );
  assert.equal(
    deriveAddress(account, 1, 0).address,
    "tb1q9u62588spffmq4dzjxsr5l297znf3z6j5p2688",
  );
});

test("accepts a ColdSigner descriptor while retaining only the account xpub", () => {
  const descriptor =
    "wpkh([73c5da0a/84'/1'/0']tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39yBA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M/0/*)#2ag6nxcd";
  assert.equal(parsePublicAccount(descriptor).fingerprintHex, "73C5DA0A");
});

test("parses BTC amounts without floating point rounding", () => {
  assert.equal(parseBtcAmount("0.00000001"), 1n);
  assert.equal(parseBtcAmount("21"), 2_100_000_000n);
  assert.equal(formatBtc(123_456_789n), "1.23456789");
  assert.throws(() => parseBtcAmount("0.000000001"));
  assert.throws(() => parseBtcAmount("-1"));
});

test("round-trips multi-frame BBQr with duplicate frames", () => {
  const payload = Uint8Array.from([
    0x70, 0x73, 0x62, 0x74, 0xff,
    ...Array.from({ length: 300 }, (_, index) => index % 256),
  ]);
  const frames = encodeBBQr(payload, 96);
  assert.ok(frames.length > 1);
  const decoder = new BBQrDecoder();
  decoder.receive(frames[0]);
  decoder.receive(frames[0]);
  let result;
  for (const frame of frames.slice(1).reverse()) result = decoder.receive(frame);
  assert.deepEqual(result?.psbt, payload);
  assert.throws(() =>
    decoder.receive(`B$HP0100${"AA".repeat(2_145)}`),
  );
});

test("finalizes the checked-in ColdSigner signed PSBT fixture", async () => {
  const [unsignedText, signedText] = await Promise.all([
    readFile(
      new URL(
        "../../Fixtures/Public/coldsigner-testnet-c03/unsigned.psbt.base64",
        import.meta.url,
      ),
      "utf8",
    ),
    readFile(
      new URL(
        "../../Fixtures/Public/coldsigner-testnet-c03/signed.psbt.base64",
        import.meta.url,
      ),
      "utf8",
    ),
  ]);
  const unsignedPSBT = Uint8Array.from(Buffer.from(unsignedText.trim(), "base64"));
  const signedPSBT = Uint8Array.from(Buffer.from(signedText.trim(), "base64"));
  const unsigned = Transaction.fromPSBT(unsignedPSBT);
  const input = unsigned.getInput(0);
  assert.ok(input.nonWitnessUtxo);
  const previousBytes = RawTx.encode(input.nonWitnessUtxo);
  const previous = Transaction.fromRaw(previousBytes);
  const account = parsePublicAccount(ORIGIN);
  const owner = deriveAddress(account, 0, 0);
  const rawPrevious = Array.from(
    previousBytes,
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
  const coin = {
    txid: previous.id,
    vout: 0,
    value: 2_000,
    status: { confirmed: true },
    owner,
  };
  verifyCoinAgainstRawTransaction(coin, rawPrevious);
  assert.throws(() =>
    verifyCoinAgainstRawTransaction({ ...coin, value: 2_001 }, rawPrevious),
  );
  const plan = {
    fee: 100n,
    unsignedTransaction: unsigned.unsignedTx,
  } as SpendPlan;
  const finalized = finalizeSignedPSBT(signedPSBT, plan);
  assert.match(finalized.rawTransactionHex, /^[0-9a-f]+$/);
  assert.match(finalized.txid, /^[0-9a-f]{64}$/);
});
