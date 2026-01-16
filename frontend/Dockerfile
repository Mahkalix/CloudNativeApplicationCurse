# syntax=docker/dockerfile:1

# =============================================================================
# Build Stage - Compile Vue.js application
# =============================================================================
FROM node:20-alpine AS build

LABEL maintainer="gym-management"
LABEL description="Gym Management Frontend"

WORKDIR /app

# Copy dependency manifests for better caching
COPY package*.json ./

# Install build dependencies
RUN npm ci

# Copy source code
COPY . .

# Build production bundle
RUN npm run build

# =============================================================================
# Runtime Stage - Nginx server
# =============================================================================
FROM nginx:1.27-alpine AS runtime

LABEL maintainer="gym-management"
LABEL description="Gym Management Frontend - Nginx"

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built assets from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Install curl for health checks and configure nginx permissions
RUN apk add --no-cache curl && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

# Expose HTTP port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://127.0.0.1/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
