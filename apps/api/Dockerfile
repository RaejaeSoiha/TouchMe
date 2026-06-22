FROM node:22-alpine AS dependencies
WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/admin/package.json apps/admin/package.json
RUN npm ci --workspace @touchme/api --include-workspace-root

FROM dependencies AS builder
COPY apps/api apps/api
RUN DATABASE_URL=postgresql://build:build@localhost:5432/build npm run prisma:generate --workspace @touchme/api && npm run build --workspace @touchme/api

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
RUN apk add --no-cache tini
USER node
WORKDIR /app
COPY --from=builder --chown=node:node /workspace/node_modules ./node_modules
COPY --from=builder --chown=node:node /workspace/apps/api/dist ./dist
COPY --from=builder --chown=node:node /workspace/apps/api/prisma ./prisma
COPY --from=builder --chown=node:node /workspace/apps/api/prisma.config.ts ./prisma.config.ts
COPY --from=builder --chown=node:node /workspace/apps/api/package.json ./package.json
EXPOSE 3000
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "dist/src/main.js"]

