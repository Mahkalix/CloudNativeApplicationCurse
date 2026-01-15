#!/bin/bash

# Script de déploiement LOCAL avec Blue/Green
# Build les images localement et déploie

set -e

echo "🏠 Déploiement LOCAL - Blue/Green"
echo "=================================="

# Charger config locale (ignorer les commentaires)
export $(grep -v '^#' .env.local | xargs)

# Couleur à déployer
COLOR=${1:-blue}

if [[ "$COLOR" != "blue" && "$COLOR" != "green" ]]; then
    echo "❌ Usage: ./scripts/deploy-local.sh [blue|green]"
    exit 1
fi

echo ""
echo "📦 Build des images Docker..."
docker compose -f docker-compose.base.yml -f docker-compose.$COLOR.yml build

echo ""
echo "🚀 Déploiement de la version $COLOR..."
docker compose -f docker-compose.base.yml -f docker-compose.$COLOR.yml up -d

echo ""
echo "⏳ Attente du démarrage des services..."
sleep 15

echo ""
echo "✅ Déploiement terminé!"
echo ""
echo "🔍 Vérification:"
docker compose ps

echo ""
echo "🌐 URLs disponibles:"
echo "  - Application: http://localhost/"
echo "  - Proxy Health: http://localhost/proxy-health"
echo "  - Version active: http://localhost/version"
echo ""
echo "📝 Pour basculer entre versions:"
echo "  ./scripts/switch-proxy-routing.sh [blue|green]"
