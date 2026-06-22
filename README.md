# TouchMe

TouchMe is a Zalo-style nearby social app: find people around you, add friends, and message anyone — no swiping or matching required.

**Stack:** NestJS API · Flutter mobile · Next.js admin · PostgreSQL/PostGIS · Redis · Socket.IO · S3 · Stripe

---

## Quick start

### 1. Start backend

```powershell
cd C:\Users\Ourmon\Desktop\TouchMe
copy .env.example .env
docker compose up --build -d
docker compose exec api npm run prisma:migrate
docker compose exec api npm run prisma:seed
```

- API docs: http://localhost:3000/docs  
- Admin: http://localhost:3001  

### 2. Start mobile (Chrome)

```powershell
cd apps\mobile
.\run-chrome.ps1
```

---

## Demo accounts

| Role | Email | Password |
|------|-------|----------|
| **Admin** | `admin@touchme.local` | `1212` |
| **Demo user** | `demo@touchme.local` | `demo12121212!` |
| **Nearby user** | `alex@touchme.local` | `demo12121212!` |
| **Nearby user** | `sam@touchme.local` | `demo12121212!` |

Legacy accounts (`demo@nearbyconnect.local`, `raejae@nearbyconnect.local`) still work if already seeded.

---

## Mobile features

| Tab | What it does |
|-----|----------------|
| **Nearby** | Browse people by distance; filter by gender, age, radius |
| **Friends** | Send/accept requests; manage your friend list |
| **Messages** | Chat with anyone — friend request not required |
| **Profile** | Photos, bio, interests, search preferences |
| **Settings** | Safety, TouchMe Plus, explore another city |

---

## Project structure

```text
apps/api       NestJS REST + WebSocket (/chat)
apps/admin     Moderation & analytics console
apps/mobile    Flutter (iOS, Android, Web) — package: touch_me
infra/         Docker, LocalStack S3, Terraform
docs/          Architecture, ERD, security, deployment
```

---

## Development commands

```powershell
npm run dev:api          # API hot reload (outside Docker)
npm run dev:admin        # Admin dev server
npm run db:migrate       # Apply migrations
npm run db:seed          # Seed interests, plans, demo users
npm run build            # Build API + admin
```

---

## Production notes

- Set strong `JWT_*_SECRET` values in `.env`
- Configure Stripe for TouchMe Plus subscriptions
- Set `SMTP_*` for password reset emails
- See `docs/deployment.md` for AWS Terraform layout
