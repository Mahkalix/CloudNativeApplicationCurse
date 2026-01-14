# syntax=docker/dockerfile:1

# =============================================================================
# Base Stage - Common configuration
# =============================================================================
FROM node:20-alpine AS base

LABEL maintainer="gym-management"
LABEL description="Gym Management Backend API"

WORKDIR /app
ENV NODE_ENV=production

# =============================================================================
# Dependencies Stage - Install and generate Prisma client
# =============================================================================
FROM base AS deps

# Install OpenSSL for Prisma
RUN apk add --no-cache openssl

# Copy dependency manifests
COPY package*.json ./

# Install production dependencies
RUN npm ci --omit=dev

# Copy Prisma schema and generate client
COPY prisma ./prisma
RUN npx prisma generate

# =============================================================================
# Production Stage - Final runtime image
# =============================================================================
FROM base AS production

WORKDIR /app

# Install runtime dependencies for Prisma engine and utilities
RUN apk add --no-cache \
    openssl \
    libssl3 \
    curl

# Copy dependencies and generated Prisma client
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/prisma ./prisma

# Copy application files
COPY --chown=node:node package*.json ./
COPY --chown=node:node src ./src
COPY --chown=node:node seed ./seed

# Switch to non-root user
USER node

# Expose application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Start application
CMD ["node", "src/index.js"]
