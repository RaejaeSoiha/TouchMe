# Production deployment

## Prerequisites

- AWS account with Route 53 or equivalent DNS, an ACM certificate, and an S3/DynamoDB Terraform backend.
- GitHub OIDC deployment role restricted to this repository and production environment.
- Stripe products/webhook, SMTP credentials, Apple/Google OAuth clients, and Firebase service credentials.

## Provision

1. Copy `infra/terraform/terraform.tfvars.example` to a secure untracked tfvars file.
2. Supply every sensitive Terraform variable through `TF_VAR_*` or an encrypted CI secret; JWT values must be independent 64+ character random strings.
3. Run `terraform init -backend-config=...`, `terraform plan`, and `terraform apply` from `infra/terraform`.
4. Point the application DNS record to `load_balancer_dns` and configure the media hostname if using a custom CloudFront certificate.
5. Terraform writes SMTP, OAuth, Firebase, Stripe, database, Redis, and JWT values into the generated Secrets Manager secret and injects them into ECS.
6. Run the API task once with `npx prisma migrate deploy --config prisma.config.ts`, then apply PostGIS with `psql $DATABASE_URL -f infra/scripts/enable-postgis.sql`, then seed plans with `npm run prisma:seed` using explicit seed passwords only in non-production.
7. Run `npm run verify:production-env -- .env.production` before registering a production task definition; the API independently fails closed when required integrations or HTTPS origins are missing.

## Release

Configure GitHub environment variables `AWS_DEPLOY_ROLE_ARN`, `AWS_REGION`, `API_ECR_REPOSITORY`, `ADMIN_ECR_REPOSITORY`, and `ECS_CLUSTER`. A version tag builds immutable images, scans them in ECR, registers new ECS task revisions, deploys API then admin, and waits for stable services. Database migrations must be executed as a reviewed one-off ECS task before a release that requires schema changes.

## Mobile release

Provide API, Socket.IO, and Firebase values through `--dart-define`; use separate Firebase apps and OAuth clients per environment. Store Android signing material and App Store Connect credentials in the CI environment, never in the repository. Run `flutter build appbundle --release` and `flutter build ipa --release` after tests, then release through staged Play and TestFlight tracks.

## Operations

Alert on ALB 5xx, API latency, ECS restarts, RDS storage/connections, Redis evictions, moderation queue age, payment webhook failures, and push delivery errors. Test point-in-time restore and incident runbooks quarterly. Rotate JWT, database, Redis, Stripe, SMTP, and OAuth credentials under a documented overlap procedure.
