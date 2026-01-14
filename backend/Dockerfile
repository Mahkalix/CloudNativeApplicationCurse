# syntax=docker/dockerfile:1
FROM node:20-alpine AS base
WORKDIR /app
ENV NODE_ENV=production

FROM base AS deps
RUN apk add --no-cache openssl
COPY package*.json ./
RUN npm ci
COPY prisma ./prisma
RUN npx prisma generate
RUN npm prune --omit=dev

FROM base AS production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/prisma ./prisma
COPY package*.json ./
COPY src ./src
COPY seed ./seed
EXPOSE 3000
RUN addgroup -S nodejs && adduser -S node -G nodejs
USER node
CMD ["node", "src/index.js"]
