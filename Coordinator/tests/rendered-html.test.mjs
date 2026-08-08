import assert from "node:assert/strict";
import test from "node:test";

const workerURL = new URL("../dist/server/index.js", import.meta.url);

async function loadWorker() {
  workerURL.searchParams.set("test", `${process.pid}-${Date.now()}-${Math.random()}`);
  return (await import(workerURL.href)).default;
}

const environment = {
  ASSETS: {
    fetch: async () => new Response("Not found", { status: 404 }),
  },
};
const context = {
  waitUntil() {},
  passThroughOnException() {},
};

test("renders the Coldbank coordinator without starter content", async () => {
  const worker = await loadWorker();
  const response = await worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html", host: "localhost" },
    }),
    environment,
    context,
  );
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const csp = response.headers.get("content-security-policy") ?? "";
  assert.match(csp, /connect-src 'self'/);
  assert.match(csp, /script-src 'self' 'nonce-[A-Za-z0-9+/]+=*' 'strict-dynamic'/);
  assert.doesNotMatch(csp.split("style-src")[0], /'unsafe-inline'/);

  const html = await response.text();
  const scriptTags = html.match(/<script[\s>]/g) ?? [];
  const noncedTags = html.match(/<script nonce="/g) ?? [];
  assert.ok(scriptTags.length > 0, "expected rendered scripts");
  assert.equal(noncedTags.length, scriptTags.length);
  assert.match(html, /<html lang="zh-CN">/);
  assert.match(html, /Coldbank/);
  assert.match(html, /在线创建交易/);
  assert.match(html, /离线确认签名/);
  assert.match(html, /Pre-alpha/);
  assert.match(html, /http:\/\/localhost\/og\.png/);
  assert.doesNotMatch(html, /codex-preview|react-loading-skeleton|Your site is taking shape/);
});

test("falls back to Blockstream for fee estimates", async () => {
  const originalFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (input) => {
    const url = String(input);
    calls.push(url);
    if (url === "https://mempool.space/testnet/api/v1/fees/recommended") {
      return new Response("busy", { status: 503 });
    }
    if (url === "https://blockstream.info/testnet/api/fee-estimates") {
      return Response.json({ 1: 11.2, 3: 7.1, 25: 2.2 });
    }
    throw new Error(`Unexpected fetch: ${url}`);
  };
  try {
    const worker = await loadWorker();
    const response = await worker.fetch(
      new Request("http://localhost/api/chain/testnet/fees", {
        headers: { "sec-fetch-site": "same-origin" },
      }),
      environment,
      context,
    );
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.equal(response.headers.get("x-coldbank-provider"), "Blockstream");
    assert.deepEqual(await response.json(), {
      fastest: 12,
      standard: 8,
      economy: 3,
      minimum: 1,
      source: "Blockstream",
    });
    assert.equal(calls.length, 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("rejects an unbounded chunked upstream response", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    const chunk = new Uint8Array(1_000_000);
    let sent = 0;
    return new Response(
      new ReadableStream({
        pull(controller) {
          if (sent >= 8) {
            controller.close();
            return;
          }
          sent += 1;
          controller.enqueue(chunk);
        },
      }),
      { status: 200 },
    );
  };
  try {
    const worker = await loadWorker();
    const response = await worker.fetch(
      new Request("http://localhost/api/chain/bitcoin/tip", {
        headers: { "sec-fetch-site": "same-origin" },
      }),
      environment,
      context,
    );
    assert.equal(response.status, 502);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("rate-limits repeated broadcasts from one client", async () => {
  const originalFetch = globalThis.fetch;
  const txid = "cd".repeat(32);
  globalThis.fetch = async () => new Response(txid, { status: 200 });
  try {
    const worker = await loadWorker();
    const send = () =>
      worker.fetch(
        new Request("http://localhost/api/chain/bitcoin/broadcast", {
          method: "POST",
          headers: {
            "sec-fetch-site": "same-origin",
            "x-expected-txid": txid,
            "cf-connecting-ip": "192.0.2.7",
            "content-type": "text/plain",
          },
          body: "02000000000100",
        }),
        environment,
        context,
      );
    for (let attempt = 0; attempt < 6; attempt += 1) {
      assert.equal((await send()).status, 200);
    }
    assert.equal((await send()).status, 429);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("checks the fallback before retrying an ambiguous broadcast", async () => {
  const originalFetch = globalThis.fetch;
  const txid = "ab".repeat(32);
  const calls = [];
  globalThis.fetch = async (input) => {
    const url = String(input);
    calls.push(url);
    if (url === "https://mempool.space/api/tx") throw new Error("timeout");
    if (url === `https://blockstream.info/api/tx/${txid}/status`) {
      return Response.json({ confirmed: false });
    }
    throw new Error(`Unexpected fetch: ${url}`);
  };
  try {
    const worker = await loadWorker();
    const response = await worker.fetch(
      new Request("http://localhost/api/chain/bitcoin/broadcast", {
        method: "POST",
        headers: {
          "sec-fetch-site": "same-origin",
          "x-expected-txid": txid,
          "content-type": "text/plain",
        },
        body: "02000000000100",
      }),
      environment,
      context,
    );
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { txid });
    assert.equal(calls.length, 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
