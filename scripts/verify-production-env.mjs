import { readFileSync } from 'node:fs';

function parseFile(path) {
  if (!path) return {};
  return Object.fromEntries(readFileSync(path, 'utf8').split(/\r?\n/).filter((line) => line && !line.startsWith('#')).map((line) => {
    const separator = line.indexOf('=');
    return [line.slice(0, separator).trim(), line.slice(separator + 1).trim().replace(/^['"]|['"]$/g, '')];
  }));
}

const env = { ...parseFile(process.argv[2]), ...process.env };
const required = ['DATABASE_URL', 'REDIS_URL', 'JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET', 'APP_ORIGINS', 'S3_BUCKET', 'S3_REGION', 'CLOUDFRONT_DOMAIN', 'STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET', 'STRIPE_PREMIUM_PRICE_ID', 'GOOGLE_CLIENT_ID', 'APPLE_CLIENT_ID', 'SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASSWORD', 'SMTP_FROM', 'FIREBASE_PROJECT_ID', 'FIREBASE_CLIENT_EMAIL', 'FIREBASE_PRIVATE_KEY'];
const missing = required.filter((key) => !env[key]);
const weak = ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'].filter((key) => (env[key]?.length ?? 0) < 64);
const placeholders = required.filter((key) => /replace|example|changeme|placeholder|your[-_]/i.test(env[key] ?? ''));
const origins = (env.APP_ORIGINS ?? '').split(',').filter(Boolean);
const errors = [];
if (env.NODE_ENV !== 'production') errors.push('NODE_ENV must be production');
if (missing.length) errors.push(`missing: ${missing.join(', ')}`);
if (weak.length) errors.push(`secrets shorter than 64 characters: ${weak.join(', ')}`);
if (placeholders.length) errors.push(`placeholder values: ${placeholders.join(', ')}`);
if (origins.some((origin) => !origin.trim().startsWith('https://'))) errors.push('APP_ORIGINS must contain HTTPS origins only');
if (env.FIREBASE_PRIVATE_KEY && !env.FIREBASE_PRIVATE_KEY.includes('BEGIN PRIVATE KEY')) errors.push('FIREBASE_PRIVATE_KEY is not a PEM private key');
if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}
console.log(JSON.stringify({ status: 'valid', checked: required.length }));
