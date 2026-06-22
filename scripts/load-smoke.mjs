import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';

const url = process.env.LOAD_URL ?? 'http://localhost:3000/api/v1/health/live';
const total = Number(process.env.LOAD_REQUESTS ?? 100);
const concurrency = Number(process.env.LOAD_CONCURRENCY ?? 20);
const maximumP95 = Number(process.env.LOAD_MAX_P95_MS ?? 500);
const latencies = [];
let failures = 0;
let cursor = 0;

async function worker() {
  while (cursor < total) {
    cursor += 1;
    const started = performance.now();
    try {
      const response = await fetch(url);
      if (!response.ok) failures += 1;
      await response.arrayBuffer();
    } catch {
      failures += 1;
    } finally {
      latencies.push(performance.now() - started);
    }
  }
}

await Promise.all(Array.from({ length: concurrency }, () => worker()));
latencies.sort((left, right) => left - right);
const percentile = (value) => latencies[Math.min(latencies.length - 1, Math.ceil(latencies.length * value) - 1)];
const report = { total, concurrency, failures, p50Ms: Math.round(percentile(0.5)), p95Ms: Math.round(percentile(0.95)), p99Ms: Math.round(percentile(0.99)) };
console.log(JSON.stringify(report));
assert.ok(failures / total <= 0.01, `failure rate exceeded 1%: ${failures}/${total}`);
assert.ok(report.p95Ms <= maximumP95, `p95 exceeded ${maximumP95}ms`);
