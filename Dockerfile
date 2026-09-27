# ---- Stage 1: Build/Install dependencies ----
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

COPY app/package*.json ./
RUN npm install --omit=dev

COPY app/ .

# ---- Stage 2: Minimal runtime image ----
FROM node:20-alpine AS runtime

# Run as non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /usr/src/app

COPY --from=builder /usr/src/app .

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]
