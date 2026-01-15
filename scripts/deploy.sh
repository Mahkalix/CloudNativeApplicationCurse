#!/usr/bin/env bash

# ========================================
# Script de déploiement automatique
# TP4 - Déploiement continu local
# ========================================

set -euo pipefail

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="${COMPOSE_FILE:-compose.yaml}"
REGISTRY="${REGISTRY:-ghcr.io}"
IMAGE_NAME="${IMAGE_NAME:-mahkalix/cloudnativeapplicationcurse}"
IMAGE_TAG="${GITHUB_SHA:-latest}"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Déploiement automatique - TP4${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Afficher les informations de déploiement
echo -e "${YELLOW}Configuration:${NC}"
echo "  Compose file: $COMPOSE_FILE"
echo "  Registry: $REGISTRY"
echo "  Image name: $IMAGE_NAME"
echo "  Image tag: $IMAGE_TAG"
echo ""

# Étape 1: Arrêt propre des conteneurs
echo -e "${YELLOW}[1/4] Arrêt des conteneurs en cours...${NC}"
if docker compose -f "$COMPOSE_FILE" ps -q | grep -q .; then
    docker compose -f "$COMPOSE_FILE" down
    echo -e "${GREEN}✓ Conteneurs arrêtés avec succès${NC}"
else
    echo -e "${BLUE}ℹ Aucun conteneur en cours d'exécution${NC}"
fi
echo ""

# Étape 2: Connexion au registre (si credentials fournis)
if [[ -n "${GHCR_TOKEN:-}" && -n "${GHCR_USER:-}" ]]; then
    echo -e "${YELLOW}[2/4] Connexion au registre...${NC}"
    echo "$GHCR_TOKEN" | docker login "$REGISTRY" -u "$GHCR_USER" --password-stdin > /dev/null 2>&1
    echo -e "${GREEN}✓ Authentification réussie${NC}"
    echo ""
fi

# Étape 3: Pull des dernières images
echo -e "${YELLOW}[3/4] Récupération des dernières images...${NC}"

# Backend
BACKEND_IMAGE="${REGISTRY}/${IMAGE_NAME}/backend:${IMAGE_TAG}"
echo "  → Backend: $BACKEND_IMAGE"
if docker pull "$BACKEND_IMAGE"; then
    echo -e "${GREEN}✓ Image backend téléchargée${NC}"
    # Tag l'image pour le compose
    docker tag "$BACKEND_IMAGE" gym-backend:latest
else
    echo -e "${RED}✗ Échec du téléchargement de l'image backend${NC}"
    exit 1
fi

# Frontend
FRONTEND_IMAGE="${REGISTRY}/${IMAGE_NAME}/frontend:${IMAGE_TAG}"
echo "  → Frontend: $FRONTEND_IMAGE"
if docker pull "$FRONTEND_IMAGE"; then
    echo -e "${GREEN}✓ Image frontend téléchargée${NC}"
    # Tag l'image pour le compose
    docker tag "$FRONTEND_IMAGE" gym-frontend:latest
else
    echo -e "${RED}✗ Échec du téléchargement de l'image frontend${NC}"
    exit 1
fi
echo ""

# Étape 4: Redémarrage de l'environnement
echo -e "${YELLOW}[4/4] Redémarrage de l'environnement...${NC}"
docker compose -f "$COMPOSE_FILE" up -d

echo -e "${GREEN}✓ Services démarrés${NC}"
echo ""

# Vérification de l'état des services
echo -e "${YELLOW}Vérification des services...${NC}"
sleep 5
docker compose -f "$COMPOSE_FILE" ps
echo ""

# Health check optionnel
if command -v curl &> /dev/null; then
    echo -e "${YELLOW}Test de santé du backend...${NC}"
    
    # Attendre que le backend soit prêt
    MAX_ATTEMPTS=30
    ATTEMPT=0
    
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        ATTEMPT=$((ATTEMPT + 1))
        echo -n "  Tentative $ATTEMPT/$MAX_ATTEMPTS... "
        
        if curl -sf http://localhost/api/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Backend opérationnel${NC}"
            break
        fi
        
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo -e "${RED}✗ Backend non accessible après $MAX_ATTEMPTS tentatives${NC}"
            echo -e "${YELLOW}Les logs backend:${NC}"
            docker compose -f "$COMPOSE_FILE" logs backend | tail -20
            exit 1
        fi
        
        echo "en attente..."
        sleep 2
    done
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Déploiement terminé avec succès !${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Application accessible sur:"
echo "  → Frontend: http://localhost (ou port configuré)"
echo "  → Backend: http://localhost:3000"
echo ""
echo "Pour voir les logs:"
echo "  docker compose -f $COMPOSE_FILE logs -f"
echo ""
