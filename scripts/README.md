# Scripts de Déploiement Blue/Green

Ce répertoire contient les scripts pour gérer le déploiement Blue/Green de l'application.

## 📁 Scripts disponibles

### `deploy-bluegreen.sh`
Script de déploiement automatisé Blue/Green utilisé par le pipeline CI/CD.

**Usage:**
```bash
./scripts/deploy-bluegreen.sh
```

**Variables d'environnement requises:**
- `REGISTRY` - Registre Docker (ex: ghcr.io)
- `IMAGE_NAME` - Nom de l'image (ex: username/repo)
- `GITHUB_SHA` - SHA du commit (ou 'latest')
- `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` - Configuration PostgreSQL
- `DATABASE_URL` - URL complète de connexion
- `NODE_ENV` - Environnement (production, staging, etc.)
- `FRONTEND_URL` - URL du frontend

**Fonctionnement:**
1. Détecte la couleur active actuelle (blue ou green)
2. Déploie la nouvelle version sur la couleur inactive
3. Effectue des health checks
4. Bascule le reverse proxy
5. Valide le déploiement

---

### `switch-deployment.sh`
Script manuel de bascule entre les versions blue et green.

**Usage:**
```bash
./scripts/switch-deployment.sh [blue|green]
```

**Exemples:**
```bash
# Basculer vers GREEN
./scripts/switch-deployment.sh green

# Rollback vers BLUE
./scripts/switch-deployment.sh blue
```

**Fonctionnement:**
1. Vérifie que la couleur cible existe et est healthy
2. Met à jour la configuration Nginx
3. Recharge Nginx (graceful reload, sans downtime)
4. Vérifie que la bascule a réussi

**Temps de bascule:** < 1 seconde

---

### `test-bluegreen.sh`
Script de validation de la configuration Blue/Green.

**Usage:**
```bash
./scripts/test-bluegreen.sh
```

**Tests effectués:**
- ✅ Présence de tous les fichiers requis
- ✅ Permissions des scripts
- ✅ Syntaxe des configurations Nginx
- ✅ Syntaxe des fichiers Docker Compose
- ✅ Validité de la couleur active
- ✅ Configuration réseau

**Quand l'utiliser:**
- Avant le premier déploiement
- Après modification des configs
- Pour débugger un problème

---

### `deploy.sh`
Script de déploiement classique (non Blue/Green) pour environnements de dev/test.

**Usage:**
```bash
./scripts/deploy.sh
```

**Utilisation:** Environnements où le Blue/Green n'est pas nécessaire.

---

## 🚀 Guide de démarrage rapide

### 1. Première installation

```bash
# Test de la configuration
./scripts/test-bluegreen.sh

# Copier les variables d'environnement
cp .env.bluegreen.example .env
# Éditer .env avec vos valeurs

# Démarrer l'infrastructure de base
docker compose -f docker-compose.base.yml up -d

# Déployer la version BLUE initiale
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml up -d

# Vérifier que tout fonctionne
curl http://localhost/proxy-health
curl http://localhost/api/health
```

### 2. Déployer une nouvelle version

```bash
# Option 1: Automatique (via CI/CD)
# → Se déclenche automatiquement sur push vers main

# Option 2: Manuelle
export REGISTRY=ghcr.io
export IMAGE_NAME=username/repo
export GITHUB_SHA=latest
export POSTGRES_DB=gym_management
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export DATABASE_URL=postgresql://postgres:postgres@postgres:5432/gym_management
export NODE_ENV=production
export FRONTEND_URL=http://localhost

./scripts/deploy-bluegreen.sh
```

### 3. Rollback d'urgence

```bash
# Si GREEN est actif, revenir à BLUE
./scripts/switch-deployment.sh blue

# Ou inversement
./scripts/switch-deployment.sh green
```

---

## 🔧 Maintenance

### Voir la couleur active

```bash
cat nginx/active_color.txt
```

### Voir les conteneurs actifs

```bash
docker ps --filter "name=gym-"
```

### Arrêter une couleur spécifique

```bash
# Arrêter GREEN (après validation de BLUE)
docker compose -f docker-compose.green.yml down

# Arrêter BLUE
docker compose -f docker-compose.blue.yml down
```

### Nettoyer complètement

```bash
# Arrêter tout
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml -f docker-compose.green.yml down

# Avec suppression des volumes (ATTENTION: perte de données)
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml -f docker-compose.green.yml down -v
```

---

## 🐛 Dépannage

### Le proxy ne démarre pas

```bash
# Vérifier les logs
docker logs gym-reverse-proxy

# Tester la config Nginx
docker exec gym-reverse-proxy nginx -t

# Reconstruire le proxy
cd nginx && docker build -t gym-reverse-proxy:latest .
docker compose -f docker-compose.base.yml up -d --force-recreate reverse-proxy
```

### Une couleur ne démarre pas

```bash
# Vérifier les logs
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml logs

# Vérifier les health checks
docker ps --format "table {{.Names}}\t{{.Status}}"

# Recréer les conteneurs
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml up -d --force-recreate
```

### La bascule ne fonctionne pas

```bash
# Vérifier la couleur active
cat nginx/active_color.txt

# Vérifier la config Nginx active
docker exec gym-reverse-proxy cat /etc/nginx/conf.d/active_routing.conf

# Forcer la bascule
./scripts/switch-deployment.sh blue  # ou green
```

---

## 📚 Documentation

- [PLAN_BLUE_GREEN.md](../PLAN_BLUE_GREEN.md) - Stratégie complète
- [README.md](../README.md) - Documentation générale
- [.github/workflows/ci.yml](../.github/workflows/ci.yml) - Pipeline CI/CD
