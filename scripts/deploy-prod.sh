#!/bin/bash

# Script de déploiement PRODUCTION avec Blue/Green
# Pull les images depuis le registry et déploie

set -e

echo "🏭 Déploiement PRODUCTION - Blue/Green"
echo "======================================"

# Charger config production (ignorer les commentaires)
export $(grep -v '^#' .env.production | xargs)

# Couleur à déployer
COLOR=${1:-blue}

if [[ "$COLOR" != "blue" && "$COLOR" != "green" ]]; then
    echo "❌ Usage: ./scripts/deploy-prod.sh [blue|green]"
    exit 1
fi

echo ""
echo "📦 Pull des images Docker depuis le registry..."
docker pull $BACKEND_IMAGE
docker pull $FRONTEND_IMAGE

echo ""
echo "🚀 Déploiement de l'infrastructure de base..."
docker compose -f docker-compose.base.yml up -d --no-build

echo ""
echo "⏳ Attente de la base de données..."
sleep 10

echo ""
echo "🔵🟢 Déploiement version $COLOR..."
docker compose -f docker-compose.base.yml -f docker-compose.$COLOR.yml up -d --no-build

echo ""
echo "⏳ Attente du démarrage des services..."
sleep 15

echo ""
echo "✅ Déploiement terminé!"
echo ""
echo "🔍 Vérification:"
docker compose ps

echo ""
echo "📝 Pour basculer entre versions:"
echo "  ./scripts/switch-proxy-routing.sh [blue|green]"
