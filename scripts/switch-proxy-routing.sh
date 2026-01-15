#!/bin/bash

# Script pour basculer le proxy entre BLUE et GREEN
# Usage: ./switch-proxy-routing.sh [blue|green]

set -e

TARGET="${1:-green}"
PROXY_CONTAINER="gym-reverse-proxy"
NGINX_DIR="/etc/nginx/conf.d"

if [[ "$TARGET" != "blue" && "$TARGET" != "green" ]]; then
    echo "❌ Usage: ./switch-proxy-routing.sh [blue|green]"
    exit 1
fi

# Définir les upstreams
case "$TARGET" in
    blue)
        BACKEND="backend_blue"
        FRONTEND="frontend_blue"
        ;;
    green)
        BACKEND="backend_green"
        FRONTEND="frontend_green"
        ;;
esac

echo "🔄 Bascule vers: $TARGET"
echo "📝 Backend: $BACKEND"
echo "📝 Frontend: $FRONTEND"

# Créer la nouvelle config avec les bons upstreams
cat > /tmp/nginx-active.conf << EOF
# Configuration Nginx pour Blue/Green Deployment
# Version active: $TARGET

# Upstream pour le backend BLUE
upstream backend_blue {
    server app-backend-blue:3000 max_fails=3 fail_timeout=30s;
}

# Upstream pour le backend GREEN
upstream backend_green {
    server app-backend-green:3000 max_fails=3 fail_timeout=30s;
}

# Upstream pour le frontend BLUE
upstream frontend_blue {
    server app-frontend-blue:80 max_fails=3 fail_timeout=30s;
}

# Upstream pour le frontend GREEN
upstream frontend_green {
    server app-frontend-green:80 max_fails=3 fail_timeout=30s;
}

# Serveur principal
server {
    listen 80;
    server_name localhost;

    # Logs
    access_log /var/log/nginx/access.log combined buffer=32k;
    error_log /var/log/nginx/error.log warn;

    # Déterminer les upstreams actifs
    set \$active_backend "$BACKEND";
    set \$active_frontend "$FRONTEND";

    # Health check du proxy lui-même
    location /proxy-health {
        access_log off;
        return 200 "Proxy OK\n";
        add_header Content-Type text/plain;
    }

    # Endpoint pour connaître la version active (debug)
    location /version {
        access_log off;
        return 200 "Active: \$active_backend\n";
        add_header Content-Type text/plain;
    }

    # Routes vers le backend (API)
    location /api/ {
        # Routage dynamique vers le backend actif
        proxy_pass http://\$active_backend;
        
        # Headers standards
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # Timeout configurations
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # Keep-alive
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # Routes vers le frontend
    location / {
        # Routage dynamique vers le frontend actif
        proxy_pass http://\$active_frontend;
        
        # Headers standards
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        
        # Timeout configurations
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Keep-alive
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/rss+xml application/atom+xml application/json 
               application/javascript;
}
EOF

# Copier le fichier dans le conteneur
echo "📦 Mise à jour de la configuration..."
docker cp /tmp/nginx-active.conf "$PROXY_CONTAINER:$NGINX_DIR/default.conf"

# Recharger Nginx
echo "🔄 Rechargement de Nginx..."
docker exec "$PROXY_CONTAINER" nginx -s reload

# Nettoyer
rm -f /tmp/nginx-active.conf

echo "✅ Bascule effectuée avec succès vers $TARGET!"
echo "📝 Active color: $TARGET" > nginx/active_color.txt

# Attendre que Nginx redémarre
sleep 2

# Vérifier la nouvelle version active
NEW_VERSION=$(curl -s http://localhost/version 2>/dev/null || echo "ERROR")
echo "✅ Version active confirmée: $NEW_VERSION"

if curl -s -f http://localhost/proxy-health > /dev/null 2>&1; then
    echo "✅ Proxy santé: OK"
else
    echo "⚠️ Proxy santé: ATTENTION"
    exit 1
fi
