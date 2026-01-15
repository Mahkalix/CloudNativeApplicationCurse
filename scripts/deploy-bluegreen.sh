#!/bin/bash

# Script de déploiement Blue/Green automatisé
# Utilisé par le pipeline CI/CD

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ACTIVE_COLOR_FILE="$PROJECT_ROOT/nginx/active_color.txt"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier les variables d'environnement requises
if [ -z "$REGISTRY" ] || [ -z "$IMAGE_NAME" ] || [ -z "$GITHUB_SHA" ]; then
    log_error "Variables d'environnement manquantes: REGISTRY, IMAGE_NAME, GITHUB_SHA"
    exit 1
fi

log_info "========================================="
log_info "Blue/Green Deployment Script"
log_info "========================================="
log_info "Registry: $REGISTRY"
log_info "Image Name: $IMAGE_NAME"
log_info "Git SHA: $GITHUB_SHA"
log_info "========================================="

# Déterminer la couleur active actuelle
if [ -f "$ACTIVE_COLOR_FILE" ]; then
    ACTIVE_COLOR=$(cat "$ACTIVE_COLOR_FILE" | tr -d '[:space:]')
else
    ACTIVE_COLOR="blue"
    echo "blue" > "$ACTIVE_COLOR_FILE"
fi

log_info "Couleur actuellement active: $ACTIVE_COLOR"

# Déterminer la couleur inactive (cible du déploiement)
if [ "$ACTIVE_COLOR" = "blue" ]; then
    TARGET_COLOR="green"
    TARGET_COMPOSE="docker-compose.green.yml"
else
    TARGET_COLOR="blue"
    TARGET_COMPOSE="docker-compose.blue.yml"
fi

log_info "Déploiement sur la couleur: $TARGET_COLOR"

# Se placer dans le répertoire du projet
cd "$PROJECT_ROOT"

# Créer le fichier .env pour le déploiement
log_info "Création du fichier .env..."
cat > .env <<EOF
REGISTRY=${REGISTRY}
IMAGE_NAME=${IMAGE_NAME}
IMAGE_TAG=${GITHUB_SHA}
POSTGRES_DB=${POSTGRES_DB:-gym_management}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
DATABASE_URL=${DATABASE_URL:-postgresql://postgres:postgres@postgres:5432/gym_management?schema=public}
NODE_ENV=${NODE_ENV:-production}
FRONTEND_URL=${FRONTEND_URL:-http://localhost}
EOF

# Login au registry si nécessaire
if [ -n "$GHCR_TOKEN" ]; then
    log_info "Connexion au registry $REGISTRY..."
    echo "$GHCR_TOKEN" | docker login -u "$GHCR_USER" --password-stdin "$REGISTRY"
fi

# S'assurer que l'infrastructure de base est démarrée
log_info "Vérification de l'infrastructure de base..."
if ! docker ps --format '{{.Names}}' | grep -q "gym-postgres"; then
    log_info "Démarrage de l'infrastructure de base (Postgres + Proxy)..."
    docker compose -f docker-compose.base.yml up -d
    log_info "Attente du démarrage de PostgreSQL..."
    sleep 10
fi

# Pull des nouvelles images

log_info "Pull des images version $TARGET_COLOR..."
MAX_PULL_RETRIES=10
PULL_RETRY_DELAY=6
PULL_ATTEMPT=1
while [ $PULL_ATTEMPT -le $MAX_PULL_RETRIES ]; do
    if docker compose -f docker-compose.base.yml -f "$TARGET_COMPOSE" pull; then
        log_success "Images $TARGET_COLOR téléchargées avec succès."
        break
    else
        log_info "Tentative $PULL_ATTEMPT/$MAX_PULL_RETRIES: les images ne sont pas encore disponibles. Nouvelle tentative dans $PULL_RETRY_DELAY s..."
        sleep $PULL_RETRY_DELAY
        PULL_ATTEMPT=$((PULL_ATTEMPT + 1))
    fi
    if [ $PULL_ATTEMPT -gt $MAX_PULL_RETRIES ]; then
        log_error "Échec du téléchargement des images $TARGET_COLOR après $MAX_PULL_RETRIES tentatives."
        exit 1
    fi
done

# Déployer la nouvelle version sur la couleur inactive
log_info "Déploiement de la version $TARGET_COLOR..."
docker compose -f docker-compose.base.yml -f "$TARGET_COMPOSE" up -d

# Attendre que les services soient healthy
log_info "Attente du démarrage des services $TARGET_COLOR..."
sleep 15

# Health checks
log_info "Health check du backend $TARGET_COLOR..."
MAX_RETRIES=30
RETRY_COUNT=0

if [ "$TARGET_COLOR" = "blue" ]; then
    BACKEND_CONTAINER="gym-backend-blue"
    FRONTEND_CONTAINER="gym-frontend-blue"
else
    BACKEND_CONTAINER="gym-backend-green"
    FRONTEND_CONTAINER="gym-frontend-green"
fi

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec "$BACKEND_CONTAINER" wget --quiet --tries=1 --spider http://localhost:3000/health 2>/dev/null; then
        log_success "Backend $TARGET_COLOR est healthy"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_info "Tentative $RETRY_COUNT/$MAX_RETRIES..."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_error "Le backend $TARGET_COLOR n'a pas démarré correctement"
    docker compose -f docker-compose.base.yml -f "$TARGET_COMPOSE" logs backend
    exit 1
fi

log_info "Health check du frontend $TARGET_COLOR..."
if ! docker exec "$FRONTEND_CONTAINER" wget --quiet --tries=1 --spider http://localhost/ 2>/dev/null; then
    log_error "Le frontend $TARGET_COLOR n'a pas démarré correctement"
    docker compose -f docker-compose.base.yml -f "$TARGET_COMPOSE" logs frontend
    exit 1
fi
log_success "Frontend $TARGET_COLOR est healthy"

# Smoke tests optionnels avant bascule
log_info "Exécution des smoke tests sur $TARGET_COLOR..."
# Vous pouvez ajouter des tests supplémentaires ici

# Bascule du reverse proxy
log_info "Bascule du reverse proxy vers $TARGET_COLOR..."

# Copier le fichier de routing
cp "$PROJECT_ROOT/nginx/active_routing_${TARGET_COLOR}.conf" "$PROJECT_ROOT/nginx/active_routing.conf"

# Mettre à jour le fichier de couleur active
echo "$TARGET_COLOR" > "$ACTIVE_COLOR_FILE"

# Copier dans le conteneur et recharger
docker cp "$PROJECT_ROOT/nginx/active_routing.conf" gym-reverse-proxy:/etc/nginx/conf.d/active_routing.conf
docker exec gym-reverse-proxy nginx -t
docker exec gym-reverse-proxy nginx -s reload

log_success "Reverse proxy basculé vers $TARGET_COLOR"

# Vérification post-bascule
sleep 3
log_info "Vérification post-bascule..."
if docker exec gym-reverse-proxy wget --quiet --tries=1 --spider http://localhost/proxy-health 2>/dev/null; then
    log_success "Reverse proxy fonctionnel"
else
    log_error "Le reverse proxy ne répond plus!"
    # Rollback automatique
    log_info "Rollback automatique vers $ACTIVE_COLOR..."
    cp "$PROJECT_ROOT/nginx/active_routing_${ACTIVE_COLOR}.conf" "$PROJECT_ROOT/nginx/active_routing.conf"
    echo "$ACTIVE_COLOR" > "$ACTIVE_COLOR_FILE"
    docker cp "$PROJECT_ROOT/nginx/active_routing.conf" gym-reverse-proxy:/etc/nginx/conf.d/active_routing.conf
    docker exec gym-reverse-proxy nginx -s reload
    exit 1
fi

# Affichage des informations de déploiement
log_success "========================================="
log_success "Déploiement réussi!"
log_success "========================================="
log_info "Version précédente: $ACTIVE_COLOR"
log_info "Version active: $TARGET_COLOR"
log_info "Image déployée: $REGISTRY/$IMAGE_NAME/backend:$GITHUB_SHA"
log_success "========================================="

# Afficher les conteneurs en cours d'exécution
log_info "Conteneurs en cours d'exécution:"
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml -f docker-compose.green.yml ps

# Note: On garde l'ancienne version running pour permettre un rollback rapide
log_info "Note: L'ancienne version ($ACTIVE_COLOR) reste active pour permettre un rollback"
log_info "Pour arrêter l'ancienne version: docker compose -f docker-compose.$ACTIVE_COLOR.yml down"
