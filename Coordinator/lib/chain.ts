import {
  deriveAddress,
  type BitcoinNetwork,
  type DerivedAddress,
  type PublicAccount,
} from "./wallet.ts";
import { Transaction } from "@scure/btc-signer";

export interface AddressSummary {
  chain_stats: {
    funded_txo_sum: number;
    spent_txo_sum: number;
    tx_count: number;
  };
  mempool_stats: {
    funded_txo_sum: number;
    spent_txo_sum: number;
    tx_count: number;
  };
}

export interface AddressUtxo {
  txid: string;
  vout: number;
  value: number;
  status: {
    confirmed: boolean;
    block_height?: number;
  };
}

export interface SpendableCoin extends AddressUtxo {
  owner: DerivedAddress;
}

export interface FeeRecommendation {
  fastest: number;
  standard: number;
  economy: number;
  minimum: number;
  source: string;
}

export interface WalletSnapshot {
  coins: SpendableCoin[];
  balance: bigint;
  nextReceive: DerivedAddress;
  nextChange: DerivedAddress;
  scannedAddressCount: number;
  provider: string;
}

function chainPath(network: BitcoinNetwork, path: string): string {
  return `/api/chain/${network}${path}`;
}

async function getJSON<T>(path: string): Promise<{ data: T; provider: string }> {
  const response = await fetch(path, {
    cache: "no-store",
    headers: { accept: "application/json" },
  });
  const data = (await response.json()) as T | { error?: string };
  if (!response.ok) {
    throw new Error(
      "error" in (data as object) && typeof (data as { error?: unknown }).error === "string"
        ? (data as { error: string }).error
        : "区块链服务暂时不可用。",
    );
  }
  return {
    data: data as T,
    provider: response.headers.get("x-coldbank-provider") ?? "mempool.space",
  };
}

async function getText(path: string): Promise<{ data: string; provider: string }> {
  const response = await fetch(path, {
    cache: "no-store",
    headers: { accept: "text/plain" },
  });
  if (!response.ok) {
    let message = "区块链服务暂时不可用。";
    try {
      const body = (await response.json()) as { error?: string };
      if (body.error) message = body.error;
    } catch {
      // Preserve the generic message.
    }
    throw new Error(message);
  }
  return {
    data: (await response.text()).trim(),
    provider: response.headers.get("x-coldbank-provider") ?? "mempool.space",
  };
}

async function mapWithConcurrency<T, R>(
  values: T[],
  concurrency: number,
  task: (value: T, index: number) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(values.length);
  let cursor = 0;
  async function worker() {
    while (cursor < values.length) {
      const index = cursor;
      cursor += 1;
      results[index] = await task(values[index], index);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, values.length) }, worker),
  );
  return results;
}

function isUsed(summary: AddressSummary): boolean {
  return summary.chain_stats.tx_count + summary.mempool_stats.tx_count > 0;
}

function sameBytes(left: Uint8Array, right: Uint8Array): boolean {
  return (
    left.length === right.length &&
    left.every((value, index) => value === right[index])
  );
}

export function verifyCoinAgainstRawTransaction(
  coin: SpendableCoin,
  rawTransactionHex: string,
): void {
  let transaction: Transaction;
  try {
    if (!/^(?:[0-9a-fA-F]{2})+$/.test(rawTransactionHex)) throw new Error();
    const bytes = Uint8Array.from(
      { length: rawTransactionHex.length / 2 },
      (_, index) =>
        Number.parseInt(
          rawTransactionHex.slice(index * 2, index * 2 + 2),
          16,
        ),
    );
    transaction = Transaction.fromRaw(bytes);
  } catch {
    throw new Error("备用数据源返回了无效的前序交易。");
  }
  const output =
    coin.vout < transaction.outputsLength
      ? transaction.getOutput(coin.vout)
      : undefined;
  if (
    transaction.id.toLowerCase() !== coin.txid.toLowerCase() ||
    !output?.script ||
    output.amount !== BigInt(coin.value) ||
    !sameBytes(output.script, coin.owner.script)
  ) {
    throw new Error("两个独立数据源对 UTXO 的结果不一致，已停止创建交易。");
  }
}

export async function getFees(
  network: BitcoinNetwork,
): Promise<FeeRecommendation> {
  return (await getJSON<FeeRecommendation>(chainPath(network, "/fees"))).data;
}

export async function scanWallet(
  account: PublicAccount,
  gapLimit = 20,
  progress?: (completed: number, total: number) => void,
): Promise<WalletSnapshot> {
  if (!Number.isInteger(gapLimit) || gapLimit < 1 || gapLimit > 50) {
    throw new Error("地址扫描范围无效。");
  }
  const addresses = ([0, 1] as const).flatMap((branch) =>
    Array.from({ length: gapLimit }, (_, index) =>
      deriveAddress(account, branch, index),
    ),
  );
  let completed = 0;
  const summaries = await mapWithConcurrency(
    addresses,
    6,
    async (owner) => {
      const result = await getJSON<AddressSummary>(
        chainPath(account.network, `/address/${owner.address}`),
      );
      completed += 1;
      progress?.(completed, addresses.length);
      return { owner, ...result };
    },
  );

  const used = summaries.filter(({ data }) => isUsed(data));
  const utxoGroups = await mapWithConcurrency(used, 6, async ({ owner }) => {
    const result = await getJSON<AddressUtxo[]>(
      chainPath(account.network, `/address/${owner.address}/utxo`),
    );
    return result.data.map((utxo) => ({
      coin: { ...utxo, owner },
      provider: result.provider,
    }));
  });
  const unverified = utxoGroups.flat();
  const verified = await mapWithConcurrency(
    unverified,
    4,
    async ({ coin, provider }) => {
      const independentSource =
        provider === "mempool.space" ? "fallback" : "primary";
      const raw = await getText(
        chainPath(
          account.network,
          `/tx/${coin.txid}/hex?source=${independentSource}`,
        ),
      );
      verifyCoinAgainstRawTransaction(coin, raw.data);
      return coin;
    },
  );
  const coins = verified;
  const receive = summaries.filter(({ owner }) => owner.branch === 0);
  const change = summaries.filter(({ owner }) => owner.branch === 1);
  const nextReceive = receive.find(({ data }) => !isUsed(data))?.owner;
  const nextChange = change.find(({ data }) => !isUsed(data))?.owner;
  if (!nextReceive || !nextChange) {
    throw new Error("连续地址扫描已到上限，请扩大 gap limit 后再操作。");
  }

  return {
    coins,
    balance: coins.reduce((sum, coin) => sum + BigInt(coin.value), 0n),
    nextReceive,
    nextChange,
    scannedAddressCount: addresses.length,
    provider: summaries[0]?.provider ?? "mempool.space",
  };
}

export async function broadcastTransaction(
  network: BitcoinNetwork,
  rawTransactionHex: string,
  expectedTxid: string,
): Promise<{ txid: string; provider: string }> {
  const response = await fetch(chainPath(network, "/broadcast"), {
    method: "POST",
    cache: "no-store",
    headers: {
      "content-type": "text/plain",
      "x-expected-txid": expectedTxid,
    },
    body: rawTransactionHex,
  });
  const data = (await response.json()) as { txid?: string; error?: string };
  if (!response.ok || !data.txid) {
    throw new Error(data.error ?? "广播失败，请先不要重复签名。");
  }
  if (data.txid.toLowerCase() !== expectedTxid.toLowerCase()) {
    throw new Error("广播服务返回了不同的交易 ID。");
  }
  return {
    txid: data.txid,
    provider: response.headers.get("x-coldbank-provider") ?? "mempool.space",
  };
}
