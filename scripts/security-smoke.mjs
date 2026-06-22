import assert from 'node:assert/strict';

const baseUrl = (process.env.SMOKE_BASE_URL ?? 'http://localhost:8080').replace(/\/$/, '');

async function request(path, options = {}) {
  return fetch(`${baseUrl}${path}`, { redirect: 'manual', ...options });
}

const ready = await request('/api/v1/health/ready');
assert.equal(ready.status, 200, 'readiness endpoint failed');
assert.match(ready.headers.get('x-content-type-options') ?? '', /nosniff/, 'nosniff header missing');
assert.match(ready.headers.get('content-security-policy') ?? '', /default-src 'none'/, 'API CSP missing');

const unauthorized = await request('/api/v1/profiles/me');
assert.equal(unauthorized.status, 401, 'protected endpoint did not reject anonymous access');

const invalidPayload = await request('/api/v1/auth/login', {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: 'nobody@example.com', password: 'not-a-password', unexpected: true }),
});
assert.equal(invalidPayload.status, 400, 'DTO whitelist did not reject an unknown property');

const injection = await request('/api/v1/auth/login', {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: "admin@example.com' OR 1=1 --", password: 'not-a-password' }),
});
assert.ok([400, 401].includes(injection.status), 'injection-shaped credentials were not rejected');

const cors = await request('/api/v1/health/live', {
  method: 'OPTIONS',
  headers: { origin: 'https://attacker.invalid', 'access-control-request-method': 'GET' },
});
assert.notEqual(cors.headers.get('access-control-allow-origin'), 'https://attacker.invalid', 'untrusted CORS origin accepted');

const csrf = await request('/admin-api/users/example/status', {
  method: 'PATCH',
  headers: { origin: 'https://attacker.invalid', 'content-type': 'application/json' },
  body: JSON.stringify({ status: 'SUSPENDED' }),
});
assert.equal(csrf.status, 403, 'admin mutation did not enforce CSRF protection');

const burst = await Promise.all(Array.from({ length: 75 }, () => request('/api/v1/health/live')));
assert.ok(burst.some((response) => response.status === 429), 'edge rate limiting did not activate');

console.log(JSON.stringify({ status: 'passed', checks: 7, baseUrl }));
