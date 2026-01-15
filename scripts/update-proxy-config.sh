#!/bin/bash

# Script pour mettre à jour la configuration du reverse proxy Nginx
# Usage: ./update-proxy-config.sh [simple|full]

set -e

CONFIG="${1:-full}"
PROXY_CONTAINER="gym-reverse-proxy"
NGINX_DIR="/etc/nginx/conf.d"

if [[ "$CONFIG" != "simple" && "$CONFIG" != "full" ]]; then
    echo "❌ Usage: ./update-proxy-config.sh [simple|full]"
    exit 1
fi

# Définir le fichier source
case "$CONFIG" in
    simple)
        SOURCE_FILE="nginx-simple.conf"
        TARGET_FILE="default.conf"
        ;;
    full)
        SOURCE_FILE="nginx-full.conf"
        TARGET_FILE="default.conf"
        ;;
esac

echo "📦 Mise à jour de la config proxy vers: $CONFIG"

# Copier le fichier dans le conteneur
docker cp "nginx/$SOURCE_FILE" "$PROXY_CONTAINER:$NGINX_DIR/$TARGET_FILE"

# Recharger Nginx
docker exec "$PROXY_CONTAINER" nginx -s reload

echo "✅ Configuration proxy mise à jour avec succès!"
echo "📝 Config actuelle: $CONFIG"

# Attendre que Nginx redémarre
sleep 2

# Vérifier la santé
if curl -s -f http://localhost/proxy-health > /dev/null 2>&1; then
    echo "✅ Proxy santé: OK"
else
    echo "⚠️ Proxy santé: ATTENTION (peut être normal si services pas déployés)"
fi
