const HEADER_LENGTH = 8;
const MAX_PARTS = 1_295;
const MAX_FRAGMENT_LENGTH = 4_296;
const MAX_PAYLOAD_BYTES = 2 * 1_024 * 1_024;
const PSBT_MAGIC = "70736274FF";

function base36(value: number): string {
  return value.toString(36).toUpperCase().padStart(2, "0");
}

export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
}

export function hexToBytes(value: string): Uint8Array {
  if (!/^(?:[0-9A-F]{2})+$/.test(value)) {
    throw new Error("BBQr 数据不是规范的大写十六进制。");
  }
  return Uint8Array.from(
    { length: value.length / 2 },
    (_, index) => Number.parseInt(value.slice(index * 2, index * 2 + 2), 16),
  );
}

export function encodeBBQr(
  psbt: Uint8Array,
  maximumFragmentLength = 360,
): string[] {
  const encoded = bytesToHex(psbt);
  if (!encoded.startsWith(PSBT_MAGIC)) {
    throw new Error("只允许编码 PSBT。");
  }
  if (psbt.length > MAX_PAYLOAD_BYTES) {
    throw new Error("PSBT 超过离线签名器的 2 MiB 上限。");
  }
  if (
    maximumFragmentLength < 64 ||
    maximumFragmentLength > MAX_FRAGMENT_LENGTH
  ) {
    throw new Error("BBQr 分片长度无效。");
  }
  const rawCapacity = maximumFragmentLength - HEADER_LENGTH;
  const bodyCapacity = rawCapacity - (rawCapacity % 2);
  const count = Math.max(1, Math.ceil(encoded.length / bodyCapacity));
  if (count > MAX_PARTS) {
    throw new Error("PSBT 太大，无法安全显示为 BBQr。");
  }
  return Array.from({ length: count }, (_, index) => {
    const body = encoded.slice(
      index * bodyCapacity,
      Math.min(encoded.length, (index + 1) * bodyCapacity),
    );
    return `B$HP${base36(count)}${base36(index)}${body}`;
  });
}

export interface BBQrProgress {
  collected: number;
  total: number;
  psbt?: Uint8Array;
}

export class BBQrDecoder {
  private total?: number;
  private readonly parts = new Map<number, string>();
  private storedCharacters = 0;

  receive(rawPart: string): BBQrProgress {
    const part = rawPart.trim();
    if (
      part !== part.toUpperCase() ||
      !part.startsWith("B$HP") ||
      part.length <= HEADER_LENGTH ||
      part.length > MAX_FRAGMENT_LENGTH
    ) {
      throw new Error("请扫描 Coldbank 的 BBQr PSBT。");
    }
    const total = Number.parseInt(part.slice(4, 6), 36);
    const index = Number.parseInt(part.slice(6, 8), 36);
    const body = part.slice(8);
    if (
      !Number.isSafeInteger(total) ||
      total < 1 ||
      total > MAX_PARTS ||
      !Number.isSafeInteger(index) ||
      index < 0 ||
      index >= total ||
      !/^(?:[0-9A-F]{2})+$/.test(body)
    ) {
      throw new Error("BBQr 分片头或内容无效。");
    }
    if (this.total !== undefined && this.total !== total) {
      this.reset();
      throw new Error("扫描到了另一笔交易，请重新开始。");
    }
    this.total = total;
    const existing = this.parts.get(index);
    if (existing !== undefined && existing !== body) {
      this.reset();
      throw new Error("同一分片内容不一致，请重新开始。");
    }
    if (existing === undefined) {
      if (this.storedCharacters + body.length > MAX_PAYLOAD_BYTES * 2) {
        this.reset();
        throw new Error("BBQr PSBT 超过 2 MiB 安全上限。");
      }
      this.parts.set(index, body);
      this.storedCharacters += body.length;
    }

    if (this.parts.size !== total) {
      return { collected: this.parts.size, total };
    }
    const regularLength = this.parts.get(0)?.length ?? 0;
    for (let cursor = 0; cursor < total - 1; cursor += 1) {
      if (this.parts.get(cursor)?.length !== regularLength) {
        this.reset();
        throw new Error("BBQr 分片长度不一致。");
      }
    }
    if ((this.parts.get(total - 1)?.length ?? 0) > regularLength) {
      this.reset();
      throw new Error("BBQr 末尾分片过长。");
    }
    const joined = Array.from(
      { length: total },
      (_, cursor) => this.parts.get(cursor) ?? "",
    ).join("");
    const psbt = hexToBytes(joined);
    this.reset();
    if (
      psbt.length > MAX_PAYLOAD_BYTES ||
      !bytesToHex(psbt).startsWith(PSBT_MAGIC)
    ) {
      throw new Error("扫描结果不是 PSBT。");
    }
    return { collected: total, total, psbt };
  }

  reset(): void {
    this.total = undefined;
    this.parts.clear();
    this.storedCharacters = 0;
  }
}
