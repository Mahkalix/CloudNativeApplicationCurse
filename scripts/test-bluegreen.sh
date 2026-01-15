#!/bin/bash

# Script de test du déploiement Blue/Green
# Vérifie que l'infrastructure est correctement configurée

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_info "========================================="
log_info "Test du déploiement Blue/Green"
log_info "========================================="

# Test 1: Vérifier les fichiers de configuration
log_info "Test 1: Vérification des fichiers..."

REQUIRED_FILES=(
    "docker-compose.base.yml"
    "docker-compose.blue.yml"
    "docker-compose.green.yml"
    "nginx/nginx-simple.conf"
    "nginx/active_routing_blue.conf"
    "nginx/active_routing_green.conf"
    "nginx/active_color.txt"
    "nginx/Dockerfile"
    "scripts/switch-deployment.sh"
    "scripts/deploy-bluegreen.sh"
    "PLAN_BLUE_GREEN.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        log_success "$file existe"
    else
        log_error "$file manquant"
        exit 1
    fi
done

# Test 2: Vérifier que les scripts sont exécutables
log_info "\nTest 2: Vérification des permissions..."

if [ -x "$PROJECT_ROOT/scripts/switch-deployment.sh" ]; then
    log_success "switch-deployment.sh est exécutable"
else
    log_error "switch-deployment.sh n'est pas exécutable"
    exit 1
fi

if [ -x "$PROJECT_ROOT/scripts/deploy-bluegreen.sh" ]; then
    log_success "deploy-bluegreen.sh est exécutable"
else
    log_error "deploy-bluegreen.sh n'est pas exécutable"
    exit 1
fi

# Test 3: Vérifier la syntaxe Nginx
log_info "\nTest 3: Vérification de la syntaxe Nginx..."

# Build temporaire de l'image Nginx pour tester la config
cd "$PROJECT_ROOT/nginx"
docker build -t gym-nginx-test:test . > /dev/null 2>&1

if [ $? -eq 0 ]; then
    log_success "Configuration Nginx valide"
    docker rmi gym-nginx-test:test > /dev/null 2>&1
else
    log_error "Configuration Nginx invalide"
    exit 1
fi

# Test 4: Vérifier la syntaxe des fichiers Docker Compose
log_info "\nTest 4: Vérification de la syntaxe Docker Compose..."

cd "$PROJECT_ROOT"

docker compose -f docker-compose.base.yml config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_success "docker-compose.base.yml valide"
else
    log_error "docker-compose.base.yml invalide"
    exit 1
fi

docker compose -f docker-compose.base.yml -f docker-compose.blue.yml config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_success "docker-compose.blue.yml valide"
else
    log_error "docker-compose.blue.yml invalide"
    exit 1
fi

docker compose -f docker-compose.base.yml -f docker-compose.green.yml config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_success "docker-compose.green.yml valide"
else
    log_error "docker-compose.green.yml invalide"
    exit 1
fi

# Test 5: Vérifier que le fichier active_color.txt contient une valeur valide
log_info "\nTest 5: Vérification de la couleur active..."

ACTIVE_COLOR=$(cat "$PROJECT_ROOT/nginx/active_color.txt" | tr -d '[:space:]')
if [ "$ACTIVE_COLOR" = "blue" ] || [ "$ACTIVE_COLOR" = "green" ]; then
    log_success "Couleur active valide: $ACTIVE_COLOR"
else
    log_error "Couleur active invalide: $ACTIVE_COLOR (doit être 'blue' ou 'green')"
    exit 1
fi

# Test 6: Vérifier la structure des réseaux Docker
log_info "\nTest 6: Vérification de la configuration réseau..."

if docker compose -f docker-compose.base.yml config | grep -q "bluegreen_net"; then
    log_success "Réseau bluegreen_net configuré"
else
    log_error "Réseau bluegreen_net manquant"
    exit 1
fi

# Résumé
log_info "\n========================================="
log_success "Tous les tests sont passés!"
log_info "========================================="
log_info ""
log_info "Pour démarrer le déploiement Blue/Green:"
log_info "  1. Copier .env.bluegreen.example vers .env"
log_info "  2. Ajuster les valeurs dans .env"
log_info "  3. Lancer: docker compose -f docker-compose.base.yml up -d"
log_info "  4. Lancer: docker compose -f docker-compose.base.yml -f docker-compose.blue.yml up -d"
log_info "  5. Tester: curl http://localhost/proxy-health"
log_info ""
log_info "Pour déployer une nouvelle version:"
log_info "  ./scripts/deploy-bluegreen.sh"
log_info ""
log_info "Pour basculer manuellement:"
log_info "  ./scripts/switch-deployment.sh [blue|green]"
log_info ""
