# Guide de Démarrage Rapide - Blue/Green Deployment

## 🚀 Quick Start

### Étape 1: Validation de la configuration

```bash
# Tester que tout est bien configuré
./scripts/test-bluegreen.sh
```

### Étape 2: Configuration des variables d'environnement

```bash
# Copier le fichier d'exemple
cp .env.bluegreen.example .env

# Éditer avec vos valeurs
nano .env
```

### Étape 3: Premier déploiement (BLUE)

```bash
# Démarrer l'infrastructure de base (PostgreSQL + Reverse Proxy)
docker compose -f docker-compose.base.yml up -d

# Attendre que PostgreSQL soit prêt (10-15 secondes)
docker compose -f docker-compose.base.yml logs -f postgres

# Déployer la version BLUE
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml up -d

# Vérifier que tout fonctionne
curl http://localhost/proxy-health
curl http://localhost/api/health
```

---

## 📦 Déployer une nouvelle version

### Méthode 1: Automatique (recommandée)

Le déploiement Blue/Green se fait **automatiquement** lors d'un push sur `main` :

1. Commit et push sur `main`
2. Le pipeline CI/CD :
   - Détecte la couleur active (ex: blue)
   - Déploie sur la couleur inactive (ex: green)
   - Effectue les health checks
   - Bascule automatiquement le proxy
   - Valide le déploiement

### Méthode 2: Manuelle

```bash
# Préparer les variables d'environnement
export REGISTRY=ghcr.io
export IMAGE_NAME=username/cloudnativeapplicationcurse
export GITHUB_SHA=latest
export POSTGRES_DB=gym_management
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export DATABASE_URL=postgresql://postgres:postgres@postgres:5432/gym_management?schema=public
export NODE_ENV=production
export FRONTEND_URL=http://localhost

# Exécuter le déploiement
./scripts/deploy-bluegreen.sh
```

### Méthode 3: Pas à pas (pour comprendre)

```bash
# 1. Déterminer la couleur active
ACTIVE=$(cat nginx/active_color.txt)
echo "Couleur active: $ACTIVE"

# Si ACTIVE=blue, déployer sur green
if [ "$ACTIVE" = "blue" ]; then
    TARGET="green"
    TARGET_FILE="docker-compose.green.yml"
else
    TARGET="blue"
    TARGET_FILE="docker-compose.blue.yml"
fi

# 2. Déployer la nouvelle version
docker compose -f docker-compose.base.yml -f $TARGET_FILE pull
docker compose -f docker-compose.base.yml -f $TARGET_FILE up -d

# 3. Attendre que les services soient prêts
sleep 15

# 4. Tester la nouvelle version
# (Les deux versions sont actives, mais le proxy route vers l'ancienne)

# 5. Basculer le proxy
./scripts/switch-deployment.sh $TARGET

# 6. Vérifier le déploiement
curl http://localhost/proxy-health
curl http://localhost/api/health
docker ps --filter "name=gym-"
```

---

## 🔄 Rollback

### Rollback instantané (< 1 seconde)

```bash
# Si GREEN est actif et pose problème, revenir à BLUE
./scripts/switch-deployment.sh blue

# Ou inversement
./scripts/switch-deployment.sh green
```

### Vérifier après rollback

```bash
# Vérifier la couleur active
cat nginx/active_color.txt

# Tester l'application
curl http://localhost/api/health
curl http://localhost/api/whoami
```

---

## 🧹 Maintenance

### Voir l'état actuel

```bash
# Couleur active
cat nginx/active_color.txt

# Conteneurs en cours d'exécution
docker ps --filter "name=gym-"

# Logs du reverse proxy
docker logs gym-reverse-proxy --tail 50

# Logs d'une couleur spécifique
docker logs gym-backend-blue --tail 50
docker logs gym-backend-green --tail 50
```

### Arrêter une ancienne version

```bash
# Une fois la nouvelle version validée, arrêter l'ancienne
# Si GREEN est maintenant actif, arrêter BLUE
docker compose -f docker-compose.blue.yml down

# Ou inversement
docker compose -f docker-compose.green.yml down
```

### Nettoyer complètement

```bash
# Arrêter toutes les services
docker compose -f docker-compose.base.yml \
               -f docker-compose.blue.yml \
               -f docker-compose.green.yml down

# Avec suppression des volumes (ATTENTION: perte de données)
docker compose -f docker-compose.base.yml \
               -f docker-compose.blue.yml \
               -f docker-compose.green.yml down -v

# Nettoyer les images
docker system prune -a
```

---

## 🐛 Résolution de problèmes

### Le proxy ne démarre pas

```bash
# Vérifier les logs
docker logs gym-reverse-proxy

# Tester la configuration Nginx
docker exec gym-reverse-proxy nginx -t

# Reconstruire le proxy
cd nginx
docker build -t gym-reverse-proxy .
cd ..
docker compose -f docker-compose.base.yml up -d --force-recreate reverse-proxy
```

### Une couleur ne démarre pas

```bash
# Vérifier les logs
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml logs

# Vérifier le health check
docker inspect gym-backend-blue | grep -A 10 Health

# Forcer la recréation
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml up -d --force-recreate
```

### La bascule échoue

```bash
# Vérifier que la couleur cible est healthy
docker exec gym-backend-green wget --quiet --tries=1 --spider http://localhost:3000/health

# Vérifier la config Nginx active
docker exec gym-reverse-proxy cat /etc/nginx/conf.d/active_routing.conf

# Forcer la bascule
./scripts/switch-deployment.sh green
```

### Base de données corrompue

```bash
# Arrêter tous les services
docker compose -f docker-compose.base.yml down

# Sauvegarder les données (si possible)
docker run --rm -v gym-app-bluegreen_pg_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres-backup.tar.gz /data

# Restaurer depuis une sauvegarde
docker run --rm -v gym-app-bluegreen_pg_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/postgres-backup.tar.gz -C /

# Ou réinitialiser complètement (PERTE DE DONNÉES)
docker volume rm gym-app-bluegreen_pg_data
docker compose -f docker-compose.base.yml up -d
```

---

## 📊 Monitoring

### Health checks en temps réel

```bash
# Surveiller les health checks
watch -n 2 'docker ps --format "table {{.Names}}\t{{.Status}}"'

# Surveiller les logs du proxy
docker logs -f gym-reverse-proxy

# Surveiller une couleur spécifique
docker logs -f gym-backend-blue
```

### Trafic réseau

```bash
# Voir les connexions actives
docker network inspect gym-app-bluegreen_bluegreen_net

# Tester la latence
time curl http://localhost/api/health

# Load test basique (nécessite 'ab' - Apache Bench)
ab -n 1000 -c 10 http://localhost/api/health
```

---

## 📝 Checklist de déploiement

Avant un déploiement en production :

- [ ] Tests passés localement
- [ ] Build Docker réussi
- [ ] Images poussées sur le registre
- [ ] Variables d'environnement configurées
- [ ] Migrations de base de données testées et rétrocompatibles
- [ ] Health checks validés
- [ ] Plan de rollback préparé
- [ ] Équipe informée du déploiement
- [ ] Monitoring en place

Pendant le déploiement :

- [ ] Couleur inactive détectée
- [ ] Nouvelle version déployée
- [ ] Health checks passés
- [ ] Tests de smoke effectués
- [ ] Bascule du proxy effectuée
- [ ] Validation post-déploiement

Après le déploiement :

- [ ] Application fonctionnelle
- [ ] Pas d'erreurs dans les logs
- [ ] Métriques normales
- [ ] Ancienne version conservée (pour rollback)
- [ ] Documentation mise à jour

---

## 🔗 Ressources

- [PLAN_BLUE_GREEN.md](PLAN_BLUE_GREEN.md) - Stratégie complète
- [scripts/README.md](scripts/README.md) - Documentation des scripts
- [README.md](README.md) - Documentation générale
- [.github/workflows/ci.yml](.github/workflows/ci.yml) - Pipeline CI/CD
