## Local Startup

# 1. Copy and configure secrets
copy .env.example .env

# 2. Start stack
docker compose up --build

# 3. Migrate + seed
docker compose exec api npm run prisma:migrate
docker compose exec api npm run prisma:seed

# 4. Open
# API Swagger: http://localhost:3000/docs
# Admin:       http://localhost:3001
# Nginx:       http://localhost:8080