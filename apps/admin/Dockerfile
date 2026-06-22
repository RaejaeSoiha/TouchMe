FROM node:22-alpine AS dependencies
WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/admin/package.json apps/admin/package.json
RUN npm ci --workspace @touchme/admin --include-workspace-root
FROM dependencies AS builder
COPY apps/admin apps/admin
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build --workspace @touchme/admin
FROM node:22-alpine AS runtime
ENV NODE_ENV=production NEXT_TELEMETRY_DISABLED=1 PORT=3001
WORKDIR /app
USER node
COPY --from=builder --chown=node:node /workspace/apps/admin/.next/standalone ./
COPY --from=builder --chown=node:node /workspace/apps/admin/.next/static ./apps/admin/.next/static
EXPOSE 3001
CMD ["node", "apps/admin/server.js"]

