import { HDKey } from "@scure/bip32";
import {
  NETWORK,
  TEST_NETWORK,
  type TArg,
  p2wpkh,
} from "@scure/btc-signer";

export type BitcoinNetwork = "bitcoin" | "testnet";

export interface PublicAccount {
  fingerprint: number;
  fingerprintHex: string;
  accountPath: [number, number, number];
  accountPathLabel: string;
  accountXpub: string;
  network: BitcoinNetwork;
}

export interface DerivedAddress {
  address: string;
  branch: 0 | 1;
  index: number;
  path: number[];
  pathLabel: string;
  publicKey: Uint8Array;
  script: Uint8Array;
}

const HARDENED = 0x8000_0000;
const TESTNET_VERSIONS = {
  private: 0x0435_8394,
  public: 0x0435_87cf,
};

export function bitcoinNetwork(network: BitcoinNetwork): TArg<typeof NETWORK> {
  return network === "bitcoin" ? NETWORK : TEST_NETWORK;
}

export function parsePublicAccount(input: string): PublicAccount {
  const normalized = input.trim();
  const match = normalized.match(
    /\[([0-9a-fA-F]{8})\/84(?:h|')\/([01])(?:h|')\/0(?:h|')\]((?:xpub|tpub)[1-9A-HJ-NP-Za-km-z]+)/,
  );
  if (!match) {
    throw new Error("请扫描 Origin xpub，格式应以 [FINGERPRINT/84h/…] 开头。");
  }

  const [, rawFingerprint, rawCoinType, accountXpub] = match;
  const coinType = Number(rawCoinType);
  const network: BitcoinNetwork = coinType === 0 ? "bitcoin" : "testnet";
  const expectedPrefix = network === "bitcoin" ? "xpub" : "tpub";
  if (!accountXpub.startsWith(expectedPrefix)) {
    throw new Error("公开账户与 BIP84 网络不一致。");
  }

  let account: HDKey;
  try {
    account = HDKey.fromExtendedKey(
      accountXpub,
      network === "bitcoin" ? undefined : TESTNET_VERSIONS,
    );
  } catch {
    throw new Error("Origin xpub 校验失败，请重新扫描离线 iPhone。");
  }
  if (account.depth !== 3 || !account.publicKey || account.privateKey) {
    throw new Error("只接受 BIP84 account-level 公开密钥。");
  }

  const fingerprintHex = rawFingerprint.toUpperCase();
  return {
    fingerprint: Number.parseInt(fingerprintHex, 16),
    fingerprintHex,
    accountPath: [84 | HARDENED, coinType | HARDENED, HARDENED],
    accountPathLabel: `m/84'/${coinType}'/0'`,
    accountXpub,
    network,
  };
}

export function deriveAddress(
  account: PublicAccount,
  branch: 0 | 1,
  index: number,
): DerivedAddress {
  if (!Number.isSafeInteger(index) || index < 0 || index >= HARDENED) {
    throw new Error("地址索引无效。");
  }
  const hd = HDKey.fromExtendedKey(
    account.accountXpub,
    account.network === "bitcoin" ? undefined : TESTNET_VERSIONS,
  )
    .deriveChild(branch)
    .deriveChild(index);
  if (!hd.publicKey) {
    throw new Error("无法派生公开密钥。");
  }
  const payment = p2wpkh(hd.publicKey, bitcoinNetwork(account.network));
  return {
    address: payment.address,
    branch,
    index,
    path: [...account.accountPath, branch, index],
    pathLabel: `${account.accountPathLabel}/${branch}/${index}`,
    publicKey: hd.publicKey,
    script: payment.script,
  };
}

export function parseBtcAmount(value: string): bigint {
  const normalized = value.trim();
  if (!/^(?:0|[1-9]\d*)(?:\.\d{0,8})?$/.test(normalized)) {
    throw new Error("金额最多支持 8 位小数。");
  }
  const [whole, fraction = ""] = normalized.split(".");
  const sats =
    BigInt(whole) * 100_000_000n +
    BigInt((fraction + "00000000").slice(0, 8));
  if (sats <= 0n || sats > 2_100_000_000_000_000n) {
    throw new Error("请输入有效的比特币金额。");
  }
  return sats;
}

export function formatBtc(sats: bigint | number): string {
  const value = typeof sats === "number" ? BigInt(sats) : sats;
  const whole = value / 100_000_000n;
  const fraction = (value % 100_000_000n)
    .toString()
    .padStart(8, "0")
    .replace(/0+$/, "");
  return fraction ? `${whole}.${fraction}` : whole.toString();
}
