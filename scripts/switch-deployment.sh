#!/bin/bash

# Script de bascule Blue/Green
# Usage: ./switch-deployment.sh [blue|green]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NGINX_DIR="$PROJECT_ROOT/nginx"
ACTIVE_COLOR_FILE="$NGINX_DIR/active_color.txt"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction d'affichage
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier les arguments
if [ $# -ne 1 ]; then
    log_error "Usage: $0 [blue|green]"
    exit 1
fi

NEW_COLOR="$1"

# Valider la couleur
if [ "$NEW_COLOR" != "blue" ] && [ "$NEW_COLOR" != "green" ]; then
    log_error "Couleur invalide: $NEW_COLOR. Utilisez 'blue' ou 'green'."
    exit 1
fi

# Lire la couleur active actuelle
if [ -f "$ACTIVE_COLOR_FILE" ]; then
    CURRENT_COLOR=$(cat "$ACTIVE_COLOR_FILE" | tr -d '[:space:]')
else
    CURRENT_COLOR="blue"
    log_warning "Fichier active_color.txt non trouvé, utilisation de 'blue' par défaut"
fi

log_info "Couleur actuelle: $CURRENT_COLOR"
log_info "Nouvelle couleur: $NEW_COLOR"

# Vérifier si un changement est nécessaire
if [ "$CURRENT_COLOR" = "$NEW_COLOR" ]; then
    log_warning "La couleur $NEW_COLOR est déjà active!"
    read -p "Voulez-vous forcer le reload du proxy? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Opération annulée"
        exit 0
    fi
fi

# Vérifier que les services de la nouvelle couleur sont démarrés
log_info "Vérification des services $NEW_COLOR..."

if [ "$NEW_COLOR" = "blue" ]; then
    BACKEND_CONTAINER="gym-backend-blue"
    FRONTEND_CONTAINER="gym-frontend-blue"
else
    BACKEND_CONTAINER="gym-backend-green"
    FRONTEND_CONTAINER="gym-frontend-green"
fi

# Vérifier que les conteneurs existent et sont en cours d'exécution
if ! docker ps --format '{{.Names}}' | grep -q "^${BACKEND_CONTAINER}$"; then
    log_error "Le conteneur $BACKEND_CONTAINER n'est pas en cours d'exécution!"
    log_info "Démarrez-le avec: docker compose -f docker-compose.base.yml -f docker-compose.$NEW_COLOR.yml up -d"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${FRONTEND_CONTAINER}$"; then
    log_error "Le conteneur $FRONTEND_CONTAINER n'est pas en cours d'exécution!"
    log_info "Démarrez-le avec: docker compose -f docker-compose.base.yml -f docker-compose.$NEW_COLOR.yml up -d"
    exit 1
fi

log_success "Services $NEW_COLOR sont actifs"

# Health check des services avant bascule
log_info "Health check du backend $NEW_COLOR..."
if ! docker exec "$BACKEND_CONTAINER" wget --quiet --tries=1 --spider http://localhost:3000/health 2>/dev/null; then
    log_error "Le backend $NEW_COLOR ne répond pas au health check!"
    exit 1
fi
log_success "Backend $NEW_COLOR est healthy"

log_info "Health check du frontend $NEW_COLOR..."
if ! docker exec "$FRONTEND_CONTAINER" wget --quiet --tries=1 --spider http://localhost/ 2>/dev/null; then
    log_error "Le frontend $NEW_COLOR ne répond pas au health check!"
    exit 1
fi
log_success "Frontend $NEW_COLOR est healthy"

# Copier le fichier de routing approprié
log_info "Mise à jour de la configuration de routing..."
cp "$NGINX_DIR/active_routing_${NEW_COLOR}.conf" "$NGINX_DIR/active_routing.conf"

# Mettre à jour le fichier de couleur active
echo "$NEW_COLOR" > "$ACTIVE_COLOR_FILE"
log_success "Fichier active_color.txt mis à jour: $NEW_COLOR"

# Copier le fichier dans le conteneur si nécessaire
docker cp "$NGINX_DIR/active_routing.conf" gym-reverse-proxy:/etc/nginx/conf.d/active_routing.conf

# Recharger la configuration Nginx (graceful reload)
log_info "Rechargement de la configuration Nginx..."
docker exec gym-reverse-proxy nginx -t
if [ $? -eq 0 ]; then
    docker exec gym-reverse-proxy nginx -s reload
    log_success "Configuration Nginx rechargée avec succès!"
else
    log_error "La configuration Nginx est invalide!"
    # Rollback
    echo "$CURRENT_COLOR" > "$ACTIVE_COLOR_FILE"
    cp "$NGINX_DIR/active_routing_${CURRENT_COLOR}.conf" "$NGINX_DIR/active_routing.conf"
    exit 1
fi

# Vérifier que le proxy fonctionne toujours
sleep 2
log_info "Vérification du reverse proxy..."
if docker exec gym-reverse-proxy wget --quiet --tries=1 --spider http://localhost/proxy-health 2>/dev/null; then
    log_success "Reverse proxy fonctionnel"
else
    log_error "Le reverse proxy ne répond plus!"
    exit 1
fi

# Afficher un récapitulatif
echo ""
log_success "========================================="
log_success "Bascule terminée avec succès!"
log_success "========================================="
echo ""
log_info "Couleur précédente: $CURRENT_COLOR"
log_info "Couleur active: $NEW_COLOR"
echo ""
log_info "Test de l'application:"
echo "  curl http://localhost/proxy-health"
echo "  curl http://localhost/api/health"
echo ""
log_warning "Pour revenir en arrière:"
echo "  $0 $CURRENT_COLOR"
echo ""
