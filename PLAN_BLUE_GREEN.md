# Plan de Déploiement Blue/Green

## 🎯 Objectif

Mettre en place une stratégie de déploiement blue/green permettant :
- **Zéro downtime** lors des déploiements
- **Rollback quasi-instantané** en cas de problème
- **Coexistence de deux versions** de l'application

---

## 🏗️ Architecture Technique

### Principe général

```
                    ┌─────────────┐
                    │   Client    │
                    └──────┬──────┘
                           │
                           ▼
                  ┌────────────────┐
                  │ Reverse Proxy  │
                  │    (Nginx)     │
                  └────────┬───────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
    ┌──────────────────┐      ┌──────────────────┐
    │   BLUE Version   │      │  GREEN Version   │
    │                  │      │                  │
    │ ┌──────────────┐ │      │ ┌──────────────┐ │
    │ │  Backend     │ │      │ │  Backend     │ │
    │ └──────────────┘ │      │ └──────────────┘ │
    │ ┌──────────────┐ │      │ ┌──────────────┐ │
    │ │  Frontend    │ │      │ │  Frontend    │ │
    │ └──────────────┘ │      │ └──────────────┘ │
    └──────────────────┘      └──────────────────┘
              │                         │
              └────────────┬────────────┘
                           │
                           ▼
                  ┌────────────────┐
                  │   PostgreSQL   │
                  │  (Partagée)    │
                  └────────────────┘
```

---

## 📁 Organisation des Fichiers Docker Compose

### Structure retenue

Nous utilisons **4 fichiers de composition** :

1. **`docker-compose.base.yml`**
   - Infrastructure partagée (Postgres + Reverse Proxy)
   - Services communs qui ne changent pas entre les déploiements
   - Une seule instance de PostgreSQL partagée entre blue et green

2. **`docker-compose.blue.yml`**
   - Services applicatifs version BLUE
   - `app-backend-blue` (port interne 3000)
   - `app-frontend-blue` (port interne 80)

3. **`docker-compose.green.yml`**
   - Services applicatifs version GREEN
   - `app-backend-green` (port interne 3001)
   - `app-frontend-green` (port interne 81)

4. **`docker-compose.proxy.yml`**
   - Configuration optionnelle pour override du proxy si nécessaire
   - Utilisé pour des tests spécifiques

### Pourquoi cette séparation ?

- **Isolation** : Déployer une couleur n'impacte pas l'autre
- **Flexibilité** : Possibilité de garder les deux versions actives
- **Simplicité** : Commandes claires et explicites

---

## 🚀 Commandes de Déploiement

### Déploiement initial (BLUE en production)

```bash
# 1. Lancer l'infrastructure de base (DB + Proxy)
docker compose -f docker-compose.base.yml up -d

# 2. Déployer la version BLUE
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml up -d

# 3. Le proxy route automatiquement vers BLUE (couleur active par défaut)
```

### Déploiement d'une nouvelle version (GREEN)

```bash
# 1. Construire et déployer GREEN (sans toucher à BLUE)
docker compose -f docker-compose.base.yml -f docker-compose.green.yml up -d

# 2. GREEN est maintenant accessible mais pas encore en production
# On peut tester GREEN avant de basculer

# 3. Basculer le reverse proxy vers GREEN
echo "green" > ./nginx/active_color.txt
docker compose -f docker-compose.base.yml restart reverse-proxy

# 4. Le trafic est maintenant routé vers GREEN
```

### Rollback vers l'ancienne version (BLUE)

```bash
# 1. Rebascule le proxy vers BLUE
echo "blue" > ./nginx/active_color.txt
docker compose -f docker-compose.base.yml restart reverse-proxy

# 2. Le trafic est de nouveau routé vers BLUE (quasi-instantané)
```

### Nettoyage de l'ancienne version

```bash
# Une fois GREEN validé en production, on peut arrêter BLUE
docker compose -f docker-compose.blue.yml down

# Ou inversement selon la couleur à nettoyer
```

---

## 🔄 Mécanisme de Bascule du Reverse Proxy

### Solution retenue : Fichier de couleur active

Le reverse proxy Nginx utilise un **fichier `active_color.txt`** pour déterminer la version active.

#### Fonctionnement :

1. **Fichier de configuration** : `nginx/active_color.txt`
   - Contient simplement `blue` ou `green`
   - Monté en volume dans le conteneur Nginx

2. **Configuration Nginx dynamique** :
   ```nginx
   # upstream définis pour les deux couleurs
   upstream backend_blue {
       server app-backend-blue:3000;
   }
   
   upstream backend_green {
       server app-backend-green:3000;
   }
   
   upstream frontend_blue {
       server app-frontend-blue:80;
   }
   
   upstream frontend_green {
       server app-frontend-green:80;
   }
   
   # Lua script ou include conditionnel pour router vers la bonne couleur
   # Basé sur la lecture de /etc/nginx/active_color.txt
   ```

3. **Bascule** :
   ```bash
   # Écrire la nouvelle couleur
   echo "green" > nginx/active_color.txt
   
   # Recharger Nginx (sans downtime)
   docker compose restart reverse-proxy
   # OU
   docker exec reverse-proxy nginx -s reload
   ```

### Alternative considérée (non retenue)

**Alias Docker** : Utiliser un alias réseau `app-active` qui pointe vers blue ou green
- ❌ Plus complexe à gérer dynamiquement
- ❌ Nécessite de recréer les conteneurs
- ✅ Notre solution avec fichier est plus simple et plus explicite

---

## 📋 Scénario de Déploiement Complet

### État Initial

- **Couleur en production** : `blue`
- **Services actifs** :
  - `postgres` (partagée)
  - `reverse-proxy` (route vers blue)
  - `app-backend-blue`
  - `app-frontend-blue`
- **Fichier** : `nginx/active_color.txt` contient `blue`

### Nouveau Déploiement

#### Phase 1 : Build et Push des images

```bash
# CI/CD construit les nouvelles images
docker build -t ghcr.io/user/repo/backend:sha123 ./backend
docker build -t ghcr.io/user/repo/frontend:sha123 ./frontend
docker push ...
```

#### Phase 2 : Déterminer la couleur inactive

```bash
# Script de déploiement lit la couleur active
ACTIVE_COLOR=$(cat nginx/active_color.txt)

# Détermine la couleur inactive
if [ "$ACTIVE_COLOR" = "blue" ]; then
  INACTIVE_COLOR="green"
  COMPOSE_FILE="docker-compose.green.yml"
else
  INACTIVE_COLOR="blue"
  COMPOSE_FILE="docker-compose.blue.yml"
fi
```

#### Phase 3 : Déployer sur la couleur inactive

```bash
# Pull des nouvelles images
docker compose -f docker-compose.base.yml -f $COMPOSE_FILE pull

# Déployer GREEN (ou BLUE si c'était GREEN qui était actif)
docker compose -f docker-compose.base.yml -f $COMPOSE_FILE up -d

# Attendre que les services soient healthy
docker compose -f docker-compose.base.yml -f $COMPOSE_FILE ps
```

#### Phase 4 : Tests de smoke sur la couleur inactive

```bash
# Tester GREEN avant de basculer (optionnel mais recommandé)
# Les deux versions sont maintenant actives, on peut tester GREEN
curl http://localhost:3001/api/health  # Backend GREEN
# Ou via un port de test exposé
```

#### Phase 5 : Bascule du proxy

```bash
# Mettre à jour la couleur active
echo "$INACTIVE_COLOR" > nginx/active_color.txt

# Recharger Nginx
docker exec reverse-proxy nginx -s reload
# OU restart du conteneur si nécessaire
docker compose -f docker-compose.base.yml restart reverse-proxy
```

#### Phase 6 : Validation

```bash
# Vérifier que le trafic passe bien par la nouvelle version
curl http://localhost/api/health
curl http://localhost/api/whoami

# Vérifier les logs
docker compose -f docker-compose.base.yml -f $COMPOSE_FILE logs --tail=50
```

#### Phase 7 : Rollback si problème

```bash
# Retour immédiat à la version précédente
echo "$ACTIVE_COLOR" > nginx/active_color.txt
docker exec reverse-proxy nginx -s reload

# Le trafic est immédiatement rerouté vers l'ancienne version
# AUCUNE interruption de service
```

#### Phase 8 : Nettoyage (optionnel)

```bash
# Une fois la nouvelle version validée, arrêter l'ancienne
OLD_COMPOSE_FILE="docker-compose.${ACTIVE_COLOR}.yml"
docker compose -f $OLD_COMPOSE_FILE down

# Libération des ressources
```

---

## 🔐 Gestion de la Base de Données

### Principe : Base de données partagée

- **Une seule instance PostgreSQL** pour blue et green
- Les migrations doivent être **rétrocompatibles**
- Stratégie : **expand-contract pattern**

### Expand-Contract Pattern

Pour éviter les problèmes lors du déploiement :

1. **Expand** (déploiement N+1) :
   - Ajouter de nouvelles colonnes (nullable)
   - Créer de nouvelles tables
   - Ancien code continue de fonctionner

2. **Deploy** :
   - Déployer le nouveau code qui utilise les nouvelles structures
   - Les deux versions (blue et green) peuvent coexister

3. **Contract** (déploiement N+2) :
   - Supprimer les anciennes colonnes/tables
   - Une fois que l'ancienne version n'est plus déployée

### Exemple de migration compatible

❌ **Mauvais** :
```sql
-- Casse la version actuelle
ALTER TABLE users DROP COLUMN old_field;
ALTER TABLE users ADD COLUMN new_field NOT NULL;
```

✅ **Bon** :
```sql
-- Compatible avec les deux versions
ALTER TABLE users ADD COLUMN new_field VARCHAR(255) NULL;
-- Le nouveau code utilise new_field
-- L'ancien code ignore new_field
-- Prochain déploiement : supprimer old_field
```

---

## ⚠️ Points d'Attention et Limitations

### Points d'attention

1. **Consommation de ressources**
   - Les deux versions peuvent tourner simultanément
   - Prévoir suffisamment de ressources (RAM, CPU)

2. **Migrations de BDD**
   - Toujours rétrocompatibles
   - Tester les migrations sur un environnement de staging

3. **État partagé**
   - Sessions utilisateurs : utiliser une base Redis partagée si nécessaire
   - Cache : préférer un cache partagé ou pas de cache local

4. **Tests avant bascule**
   - Possibilité d'accéder à la version inactive via un port alternatif
   - Smoke tests automatisés recommandés

### Limitations

1. **Rollback de BDD impossible**
   - Si une migration est appliquée, le rollback ne l'annulera pas
   - Solution : migrations compatibles avec les deux versions

2. **Ressources doublées temporairement**
   - Pendant le déploiement, 2x backend + 2x frontend actifs
   - Pas idéal pour environnements avec peu de ressources

3. **Complexité additionnelle**
   - Plus de fichiers à maintenir
   - Nécessite une discipline sur les migrations

---

## ✅ Validation de la Stratégie

### Critères de réussite

- ✅ Nouvelle version déployée sans arrêter l'ancienne
- ✅ Bascule du proxy sans interruption de service (< 1s)
- ✅ Rollback possible en moins de 10 secondes
- ✅ Les deux versions peuvent coexister
- ✅ Base de données partagée sans conflit

### Tests à effectuer

1. **Test de déploiement** :
   - Déployer GREEN pendant que BLUE est actif
   - Vérifier que BLUE reste accessible

2. **Test de bascule** :
   - Basculer de BLUE à GREEN
   - Mesurer le temps de coupure (doit être < 1s)
   - Vérifier que les utilisateurs ne voient pas d'erreur

3. **Test de rollback** :
   - Basculer de GREEN à BLUE
   - Vérifier que c'est quasi-instantané

4. **Test de charge** (optionnel) :
   - Générer du trafic pendant la bascule
   - Vérifier qu'aucune requête n'est perdue

---

## 🎓 Conclusion

Cette stratégie blue/green offre :
- **Zéro downtime** garanti
- **Rollback trivial** (changement de fichier + reload)
- **Flexibilité** pour tester avant de basculer
- **Simplicité** de mise en œuvre avec Docker Compose

Le point critique est la **compatibilité des migrations** de base de données, qui nécessite une discipline et une planification.
