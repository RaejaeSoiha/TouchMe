# Security

## Authentication

- Short-lived JWT access tokens (default 15m) and rotating refresh tokens (30d).
- Refresh token families detect reuse; compromised families are revoked.
- Admin console uses HTTP-only session cookies separate from mobile JWTs.

## Authorization

- Users can only access conversations they belong to.
- Friend actions require active accounts and pass block checks.
- Admin routes require `ADMIN` or `MODERATOR` role; moderation actions are audited.

## Safety

- Block checks are enforced in nearby discovery, friend requests, messaging, and notifications.
- Reports preserve evidence and enter an audited review queue in the admin console.
- Media uploads are scanned for size/type; profile photos can be moderated before approval.

## Transport and storage

- TLS in production; HSTS via Nginx/CloudFront.
- Passwords hashed with Argon2; refresh tokens stored hashed only.
- S3 presigned URLs for media; clients never receive AWS credentials.
- PII minimized in logs; request IDs for traceability.

## Rate limiting

- Global API throttling via Redis-backed NestJS throttler.
- WebSocket message spam guard (30 messages / 10s per user).
- OTP and login endpoints have stricter per-route limits.
