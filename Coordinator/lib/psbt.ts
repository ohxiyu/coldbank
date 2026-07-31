import {
  SigHash,
  Transaction,
} from "@scure/btc-signer";
import type { SpendableCoin } from "./chain.ts";
import {
  bitcoinNetwork,
  type DerivedAddress,
  type PublicAccount,
} from "./wallet.ts";

const DUST_LIMIT = 294n;
const MAX_INPUTS = 200;
const MAX_FEE_SATS = 100_000n;

export interface SpendPlan {
  account: PublicAccount;
  selected: SpendableCoin[];
  recipient: string;
  amount: bigint;
  fee: bigint;
  feeRate: number;
  change: bigint;
  changeAddress?: DerivedAddress;
  psbt: Uint8Array;
  unsignedTransaction: Uint8Array;
}

function estimatedVbytes(inputs: number, outputs: number): bigint {
  return BigInt(10 + inputs * 68 + outputs * 31);
}

function sameBytes(left: Uint8Array, right: Uint8Array): boolean {
  return (
    left.length === right.length &&
    left.every((value, index) => value === right[index])
  );
}

export function createSpendPlan(
  account: PublicAccount,
  coins: SpendableCoin[],
  recipient: string,
  amount: bigint,
  feeRate: number,
  changeAddress: DerivedAddress,
): SpendPlan {
  if (!Number.isFinite(feeRate) || feeRate < 1 || feeRate > 500) {
    throw new Error("费率必须在 1–500 sat/vB 之间。");
  }
  const sorted = [...coins].sort((left, right) => right.value - left.value);
  const selected: SpendableCoin[] = [];
  let total = 0n;
  let fee = 0n;
  for (const coin of sorted) {
    selected.push(coin);
    total += BigInt(coin.value);
    fee = BigInt(Math.ceil(Number(estimatedVbytes(selected.length, 2)) * feeRate));
    if (total >= amount + fee) break;
  }
  if (selected.length === 0 || total < amount + fee) {
    throw new Error("余额不足以支付金额和矿工费。");
  }
  if (selected.length > MAX_INPUTS) {
    throw new Error("输入数量超过离线签名器的安全上限。");
  }

  let change = total - amount - fee;
  let actualChangeAddress: DerivedAddress | undefined = changeAddress;
  if (change < DUST_LIMIT) {
    fee = total - amount;
    change = 0n;
    actualChangeAddress = undefined;
  }
  if (fee <= 0n || fee > MAX_FEE_SATS || fee * 20n > amount) {
    throw new Error("矿工费超过安全上限，请降低费率或调整金额。");
  }

  const tx = new Transaction({ PSBTVersion: 0 });
  for (const coin of selected) {
    tx.addInput({
      txid: coin.txid,
      index: coin.vout,
      sequence: 0xffff_fffd,
      witnessUtxo: {
        amount: BigInt(coin.value),
        script: coin.owner.script,
      },
      sighashType: SigHash.ALL,
      bip32Derivation: [
        [
          coin.owner.publicKey,
          {
            fingerprint: account.fingerprint,
            path: coin.owner.path,
          },
        ],
      ],
    });
  }

  try {
    tx.addOutputAddress(
      recipient.trim(),
      amount,
      bitcoinNetwork(account.network),
    );
  } catch {
    throw new Error("收款地址无效，或与钱包网络不一致。");
  }
  if (actualChangeAddress) {
    tx.addOutput({
      script: actualChangeAddress.script,
      amount: change,
      bip32Derivation: [
        [
          actualChangeAddress.publicKey,
          {
            fingerprint: account.fingerprint,
            path: actualChangeAddress.path,
          },
        ],
      ],
    });
  }

  return {
    account,
    selected,
    recipient: recipient.trim(),
    amount,
    fee,
    feeRate,
    change,
    changeAddress: actualChangeAddress,
    psbt: tx.toPSBT(0),
    unsignedTransaction: tx.unsignedTx,
  };
}

export function finalizeSignedPSBT(
  signedPSBT: Uint8Array,
  plan: SpendPlan,
): { rawTransactionHex: string; txid: string } {
  let signed: Transaction;
  try {
    signed = Transaction.fromPSBT(signedPSBT, { PSBTVersion: 0 });
  } catch {
    throw new Error("签名结果不是有效的 PSBT v0。");
  }
  if (!sameBytes(signed.unsignedTx, plan.unsignedTransaction)) {
    throw new Error("签名结果对应另一笔交易，已拒绝广播。");
  }
  if (signed.fee !== plan.fee) {
    throw new Error("签名结果中的矿工费发生变化，已拒绝广播。");
  }
  try {
    signed.finalize();
    const raw = signed.extract();
    const finalized = Transaction.fromRaw(raw);
    return { rawTransactionHex: finalized.hex, txid: finalized.id };
  } catch {
    throw new Error("签名不完整，请在离线 iPhone 上重新签名。");
  }
}
