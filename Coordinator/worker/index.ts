import {
  DEFAULT_DEVICE_SIZES,
  DEFAULT_IMAGE_SIZES,
  handleImageOptimization,
} from "vinext/server/image-optimization";
import handler from "vinext/server/app-router-entry";

interface Env {
  ASSETS: {
    fetch(request: Request): Promise<Response> | Response;
  };
  IMAGES?: {
    input(stream: ReadableStream): {
      transform(options: Record<string, unknown>): {
        output(options: {
          format: string;
          quality: number;
        }): Promise<{ response(): Response }>;
      };
    };
  };
  MEMPOOL_API_URL?: string;
  MEMPOOL_TESTNET_API_URL?: string;
  BLOCKSTREAM_API_URL?: string;
  BLOCKSTREAM_TESTNET_API_URL?: string;
}

interface ExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
  passThroughOnException(): void;
}

type Network = "bitcoin" | "testnet";
type Provider = { name: "mempool.space" | "Blockstream"; baseURL: string };

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "referrer-policy": "no-referrer",
  "x-content-type-options": "nosniff",
};

const MAX_UPSTREAM_BODY_BYTES = 5_000_000;

function contentSecurityPolicy(nonce?: string): string {
  const script = nonce
    ? `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'`
    : "script-src 'self'";
  return [
    "default-src 'self'",
    script,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "connect-src 'self'",
    "media-src 'self' blob:",
    "object-src 'none'",
    "base-uri 'none'",
    "frame-ancestors 'none'",
    "form-action 'self'",
  ].join("; ");
}

function scriptNonce(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes));
}

// Reads an upstream body while enforcing a byte budget, because
// content-length is absent on chunked responses. Returns null when the
// upstream exceeds the budget.
async function readBoundedText(response: Response): Promise<string | null> {
  const body = response.body;
  if (!body) {
    const text = await response.text();
    return text.length > MAX_UPSTREAM_BODY_BYTES ? null : text;
  }
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let received = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    received += value.byteLength;
    if (received > MAX_UPSTREAM_BODY_BYTES) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const merged = new Uint8Array(received);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(merged);
}

async function readBoundedJSON(response: Response): Promise<unknown | null> {
  const text = await readBoundedText(response);
  if (text === null) return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return null;
  }
}

function json(
  body: unknown,
  status = 200,
  provider?: Provider,
): Response {
  const headers = new Headers(JSON_HEADERS);
  if (provider) headers.set("x-coldbank-provider", provider.name);
  return new Response(JSON.stringify(body), { status, headers });
}

function providers(env: Env, network: Network): Provider[] {
  return network === "bitcoin"
    ? [
        {
          name: "mempool.space",
          baseURL: env.MEMPOOL_API_URL ?? "https://mempool.space/api",
        },
        {
          name: "Blockstream",
          baseURL:
            env.BLOCKSTREAM_API_URL ?? "https://blockstream.info/api",
        },
      ]
    : [
        {
          name: "mempool.space",
          baseURL:
            env.MEMPOOL_TESTNET_API_URL ??
            "https://mempool.space/testnet/api",
        },
        {
          name: "Blockstream",
          baseURL:
            env.BLOCKSTREAM_TESTNET_API_URL ??
            "https://blockstream.info/testnet/api",
        },
      ];
}

function retryable(response: Response): boolean {
  return response.status === 429 || response.status >= 500;
}

async function upstream(
  provider: Provider,
  path: string,
  init?: RequestInit,
): Promise<Response> {
  return fetch(`${provider.baseURL}${path}`, {
    ...init,
    redirect: "error",
    signal: AbortSignal.timeout(8_000),
  });
}

async function withFallback(
  candidates: Provider[],
  path: string,
  init?: RequestInit,
): Promise<{ response: Response; provider: Provider }> {
  let lastStatus = 502;
  for (const provider of candidates) {
    try {
      const response = await upstream(provider, path, init);
      lastStatus = response.status;
      if (response.ok || !retryable(response)) {
        return { response, provider };
      }
    } catch {
      lastStatus = 504;
    }
  }
  throw new Error(`upstream:${lastStatus}`);
}

async function relayJSON(
  candidates: Provider[],
  path: string,
): Promise<Response> {
  try {
    const { response, provider } = await withFallback(candidates, path, {
      headers: { accept: "application/json" },
    });
    if (!response.ok) {
      return json(
        { error: response.status === 404 ? "未找到链上数据。" : "链上数据请求失败。" },
        response.status,
        provider,
      );
    }
    const value = await readBoundedJSON(response);
    if (value === null) return json({ error: "上游响应过大或格式无效。" }, 502);
    return json(value, 200, provider);
  } catch {
    return json({ error: "mempool.space 与备用服务暂时都不可用。" }, 503);
  }
}

async function relayText(
  candidates: Provider[],
  path: string,
): Promise<Response> {
  try {
    const { response, provider } = await withFallback(candidates, path, {
      headers: { accept: "text/plain" },
    });
    if (!response.ok) {
      return json(
        { error: response.status === 404 ? "未找到链上数据。" : "链上数据请求失败。" },
        response.status,
        provider,
      );
    }
    const bounded = await readBoundedText(response);
    if (bounded === null) return json({ error: "上游响应过大。" }, 502);
    const text = bounded.trim();
    const headers = new Headers(JSON_HEADERS);
    headers.set("content-type", "text/plain; charset=utf-8");
    headers.set("x-coldbank-provider", provider.name);
    return new Response(text, { status: 200, headers });
  } catch {
    return json({ error: "mempool.space 与备用服务暂时都不可用。" }, 503);
  }
}

async function feeResponse(
  candidates: Provider[],
): Promise<Response> {
  const primary = candidates[0];
  try {
    const response = await upstream(primary, "/v1/fees/recommended", {
      headers: { accept: "application/json" },
    });
    if (response.ok) {
      const parsed = await readBoundedJSON(response);
      if (parsed === null) return json({ error: "费率服务响应无效。" }, 502, primary);
      const value = parsed as Record<string, number>;
      return json(
        {
          fastest: Math.ceil(value.fastestFee),
          standard: Math.ceil(value.hourFee ?? value.halfHourFee),
          economy: Math.ceil(value.economyFee),
          minimum: Math.max(1, Math.ceil(value.minimumFee)),
          source: primary.name,
        },
        200,
        primary,
      );
    }
    if (!retryable(response)) {
      return json({ error: "费率服务拒绝了请求。" }, response.status, primary);
    }
  } catch {
    // Continue to the independent Esplora fallback.
  }

  const fallback = candidates[1];
  try {
    const response = await upstream(fallback, "/fee-estimates", {
      headers: { accept: "application/json" },
    });
    if (!response.ok) {
      return json({ error: "备用费率服务不可用。" }, 503, fallback);
    }
    const parsed = await readBoundedJSON(response);
    if (parsed === null) return json({ error: "备用费率服务响应无效。" }, 502, fallback);
    const value = parsed as Record<string, number>;
    const at = (...targets: string[]) =>
      Math.ceil(
        targets.map((target) => value[target]).find(Number.isFinite) ?? 1,
      );
    return json(
      {
        fastest: at("1", "2"),
        standard: at("3", "6"),
        economy: at("25", "144"),
        minimum: 1,
        source: fallback.name,
      },
      200,
      fallback,
    );
  } catch {
    return json({ error: "两个费率服务都暂时不可用。" }, 503);
  }
}

// Best-effort per-isolate rate limit for the only state-changing endpoint.
// Cloudflare may run many isolates, so this bounds abuse per isolate only;
// account-level rate limiting rules remain the outer control.
const BROADCAST_RATE_LIMIT = 6;
const BROADCAST_RATE_WINDOW_MS = 60_000;
const broadcastHistory = new Map<string, number[]>();

function broadcastAllowed(request: Request, now = Date.now()): boolean {
  const client = request.headers.get("cf-connecting-ip") ?? "unknown";
  const recent = (broadcastHistory.get(client) ?? []).filter(
    (at) => now - at < BROADCAST_RATE_WINDOW_MS,
  );
  if (recent.length >= BROADCAST_RATE_LIMIT) {
    broadcastHistory.set(client, recent);
    return false;
  }
  recent.push(now);
  if (broadcastHistory.size > 10_000) broadcastHistory.clear();
  broadcastHistory.set(client, recent);
  return true;
}

async function broadcast(
  request: Request,
  candidates: Provider[],
): Promise<Response> {
  if (!broadcastAllowed(request)) {
    return json({ error: "广播请求过于频繁，请稍后再试。" }, 429);
  }
  const expectedTxid = request.headers.get("x-expected-txid")?.toLowerCase();
  if (!expectedTxid || !/^[0-9a-f]{64}$/.test(expectedTxid)) {
    return json({ error: "缺少有效的预期交易 ID。" }, 400);
  }
  const raw = (await request.text()).trim();
  if (!/^(?:[0-9a-fA-F]{2})+$/.test(raw) || raw.length > 800_000) {
    return json({ error: "原始交易格式无效或过大。" }, 400);
  }

  const primary = candidates[0];
  try {
    const response = await upstream(primary, "/tx", {
      method: "POST",
      headers: { "content-type": "text/plain" },
      body: raw,
    });
    if (response.ok) {
      const txid = (await response.text()).trim().toLowerCase();
      return txid === expectedTxid
        ? json({ txid }, 200, primary)
        : json({ error: "上游返回了不同的交易 ID。" }, 502, primary);
    }
    if (!retryable(response)) {
      return json({ error: "交易被 Bitcoin 网络拒绝。" }, 400, primary);
    }
  } catch {
    // A timeout can happen after acceptance. Check the expected txid first.
  }

  const fallback = candidates[1];
  try {
    const status = await upstream(fallback, `/tx/${expectedTxid}/status`, {
      headers: { accept: "application/json" },
    });
    if (status.ok) return json({ txid: expectedTxid }, 200, fallback);
    const response = await upstream(fallback, "/tx", {
      method: "POST",
      headers: { "content-type": "text/plain" },
      body: raw,
    });
    if (!response.ok) {
      return json({ error: "主服务状态不明，备用服务也未接受交易。" }, 503, fallback);
    }
    const txid = (await response.text()).trim().toLowerCase();
    return txid === expectedTxid
      ? json({ txid }, 200, fallback)
      : json({ error: "备用服务返回了不同的交易 ID。" }, 502, fallback);
  } catch {
    return json({ error: "广播状态不明。请按交易 ID 查询后再决定是否重试。" }, 503);
  }
}

async function handleChainAPI(request: Request, env: Env): Promise<Response> {
  if (request.headers.get("sec-fetch-site") === "cross-site") {
    return json({ error: "不接受跨站请求。" }, 403);
  }
  const url = new URL(request.url);
  const match = url.pathname.match(/^\/api\/chain\/(bitcoin|testnet)(\/.*)$/);
  if (!match) return json({ error: "接口不存在。" }, 404);
  const network = match[1] as Network;
  const path = match[2];
  const candidates = providers(env, network);

  if (request.method === "GET" && path === "/fees") {
    return feeResponse(candidates);
  }
  if (request.method === "GET" && path === "/tip") {
    return relayJSON(candidates, "/blocks/tip/height");
  }
  const address = path.match(/^\/address\/([A-Za-z0-9]{14,90})(\/utxo)?$/);
  if (request.method === "GET" && address) {
    return relayJSON(
      candidates,
      `/address/${address[1]}${address[2] ?? ""}`,
    );
  }
  const transaction = path.match(/^\/tx\/([0-9a-fA-F]{64})\/(hex|status)$/);
  if (request.method === "GET" && transaction) {
    const source = url.searchParams.get("source");
    const selected =
      source === "fallback"
        ? [candidates[1]]
        : source === "primary"
          ? [candidates[0]]
          : candidates;
    const upstreamPath =
      `/tx/${transaction[1].toLowerCase()}/${transaction[2]}`;
    return transaction[2] === "hex"
      ? relayText(selected, upstreamPath)
      : relayJSON(selected, upstreamPath);
  }
  if (request.method === "POST" && path === "/broadcast") {
    return broadcast(request, candidates);
  }
  return json({ error: "接口不存在或方法不允许。" }, 404);
}

const worker = {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname.startsWith("/api/chain/")) {
      return handleChainAPI(request, env);
    }

    if (url.pathname === "/_vinext/image" && env.IMAGES) {
      const allowedWidths = [...DEFAULT_DEVICE_SIZES, ...DEFAULT_IMAGE_SIZES];
      return handleImageOptimization(
        request,
        {
          fetchAsset: (path) =>
            Promise.resolve(
              env.ASSETS.fetch(new Request(new URL(path, request.url))),
            ),
          transformImage: async (body, { width, format, quality }) => {
            const result = await env.IMAGES!.input(body)
              .transform(width > 0 ? { width } : {})
              .output({ format, quality });
            return result.response();
          },
        },
        allowedWidths,
      );
    }

    const response = await handler.fetch(request, env, ctx);
    const headers = new Headers(response.headers);
    headers.set("referrer-policy", "no-referrer");
    headers.set("x-content-type-options", "nosniff");
    headers.set(
      "permissions-policy",
      "camera=(self), geolocation=(), microphone=(), payment=(), usb=()",
    );

    const contentType = (headers.get("content-type") ?? "").toLowerCase();
    if (contentType.includes("text/html")) {
      // Framework HTML carries dynamic inline scripts, so hash-based CSP is
      // impossible; stamp a per-request nonce on every script tag instead.
      // Inline JSON payloads unicode-escape the "<" character, so the
      // rewrite only touches real script tags.
      const nonce = scriptNonce();
      const html = (await response.text()).replace(
        /<script(?=[\s>])/g,
        `<script nonce="${nonce}"`,
      );
      headers.set("content-security-policy", contentSecurityPolicy(nonce));
      headers.delete("content-length");
      headers.delete("content-encoding");
      return new Response(html, {
        status: response.status,
        statusText: response.statusText,
        headers,
      });
    }

    headers.set("content-security-policy", contentSecurityPolicy());
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  },
};

export default worker;
