# Gym Management System

[![CI Pipeline](https://github.com/Mahkalix/CloudNativeApplicationCurse/actions/workflows/ci.yml/badge.svg)](https://github.com/Mahkalix/CloudNativeApplicationCurse/actions)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=Mahkalix_CloudNativeApplicationCurse&metric=alert_status)](https://sonarcloud.io/summary/overall_health?id=Mahkalix_CloudNativeApplicationCurse)
[![Code Coverage](https://sonarcloud.io/api/project_badges/measure?project=Mahkalix_CloudNativeApplicationCurse&metric=coverage)](https://sonarcloud.io/summary/overall_health?id=Mahkalix_CloudNativeApplicationCurse)

A complete fullstack gym management application built with modern web technologies.

## Features

### User Features
- **User Dashboard**: View stats, billing, and recent bookings
- **Class Booking**: Book and cancel fitness classes
- **Subscription Management**: View subscription details and billing
- **Profile Management**: Update personal information

### Admin Features
- **Admin Dashboard**: Overview of gym statistics and revenue
- **User Management**: CRUD operations for users
- **Class Management**: Create, update, and delete fitness classes
- **Booking Management**: View and manage all bookings
- **Subscription Management**: Manage user subscriptions

### Business Logic
- **Capacity Management**: Classes have maximum capacity limits
- **Time Conflict Prevention**: Users cannot book overlapping classes
- **Cancellation Policy**: 2-hour cancellation policy (late cancellations become no-shows)
- **Billing System**: Dynamic pricing with no-show penalties
- **Subscription Types**: Standard (€30), Premium (€50), Student (€20)

## Tech Stack

### Backend
- **Node.js** with Express.js
- **Prisma** ORM with PostgreSQL
- **RESTful API** with proper error handling
- **MVC Architecture** with repositories pattern

### Frontend
- **Vue.js 3** with Composition API
- **Pinia** for state management
- **Vue Router** with navigation guards
- **Responsive CSS** styling

### DevOps
- **Docker** containerization
- **Docker Compose** for orchestration
- **PostgreSQL** database
- **Nginx** for frontend serving

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd gym-management-system
   ```

2. **Set up environment variables**
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` file if needed (default values should work for development).

3. **Start the application**
   ```bash
   docker-compose up --build
   ```

4. **Access the application**
   - Frontend: http://localhost:8080
   - Backend API: http://localhost:3000
   - Database: localhost:5432

### Default Login Credentials

The application comes with seeded test data:

**Admin User:**
- Email: admin@gym.com
- Password: admin123
- Role: ADMIN

**Regular Users:**
- Email: john.doe@email.com
- Email: jane.smith@email.com  
- Email: mike.wilson@email.com
- Password: password123 (for all users)

## Project Structure

```
gym-management-system/
├── backend/
│   ├── src/
│   │   ├── controllers/     # Request handlers
│   │   ├── services/        # Business logic
│   │   ├── repositories/    # Data access layer
│   │   ├── routes/          # API routes
│   │   └── prisma/          # Database schema and client
│   ├── seed/                # Database seeding
│   └── Dockerfile
├── frontend/
│   ├── src/
│   │   ├── views/           # Vue components/pages
│   │   ├── services/        # API communication
│   │   ├── store/           # Pinia stores
│   │   └── router/          # Vue router
│   ├── Dockerfile
│   └── nginx.conf
└── docker-compose.yml
```

## API Endpoints

### Authentication
- `POST /api/auth/login` - User login

### Users
- `GET /api/users` - Get all users
- `GET /api/users/:id` - Get user by ID
- `POST /api/users` - Create user
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

### Classes
- `GET /api/classes` - Get all classes
- `GET /api/classes/:id` - Get class by ID
- `POST /api/classes` - Create class
- `PUT /api/classes/:id` - Update class
- `DELETE /api/classes/:id` - Delete class

### Bookings
- `GET /api/bookings` - Get all bookings
- `GET /api/bookings/user/:userId` - Get user bookings
- `POST /api/bookings` - Create booking
- `PUT /api/bookings/:id/cancel` - Cancel booking
- `DELETE /api/bookings/:id` - Delete booking

### Subscriptions
- `GET /api/subscriptions` - Get all subscriptions
- `GET /api/subscriptions/user/:userId` - Get user subscription
- `POST /api/subscriptions` - Create subscription
- `PUT /api/subscriptions/:id` - Update subscription

### Dashboard
- `GET /api/dashboard/user/:userId` - Get user dashboard
- `GET /api/dashboard/admin` - Get admin dashboard

## Development

### Local Development Setup

1. **Backend Development**
   ```bash
   cd backend
   npm install
   npm run dev
   ```

2. **Frontend Development**
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

3. **Database Setup**
   ```bash
   cd backend
   npx prisma migrate dev
   npm run seed
   ```

### Database Management

- **View Database**: `npx prisma studio`
- **Reset Database**: `npx prisma db reset`
- **Generate Client**: `npx prisma generate`
- **Run Migrations**: `npx prisma migrate deploy`

### Useful Commands

```bash
# Stop all containers
docker-compose down

# View logs
docker-compose logs -f [service-name]

# Rebuild specific service
docker-compose up --build [service-name]

# Access database
docker exec -it gym_db psql -U postgres -d gym_management
```

## Features in Detail

### Subscription System
- **STANDARD**: €30/month, €5 per no-show
- **PREMIUM**: €50/month, €3 per no-show  
- **ETUDIANT**: €20/month, €7 per no-show

### Booking Rules
- Users can only book future classes
- Maximum capacity per class is enforced
- No double-booking at the same time slot
- 2-hour cancellation policy

### Admin Dashboard
- Total users and active subscriptions
- Booking statistics (confirmed, no-show, cancelled)
- Monthly revenue calculations
- User management tools

### User Dashboard
- Personal statistics and activity
- Current subscription details
- Monthly billing with no-show penalties
- Recent booking history

## CI/CD Pipeline

### 📊 Schéma du Pipeline Complet (avec Déploiement Continu)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Git Push Event (main)                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────┐                                              │
│  │   1. Code Quality    │                                              │
│  │  ✓ ESLint Frontend   │                                              │
│  │  ✓ ESLint Backend    │                                              │
│  │  ✓ Prettier Format   │                                              │
│  └──────────────────────┘                                              │
│           │                                                             │
│           ↓                                                             │
│  ┌──────────────────────┐                                              │
│  │   2. Build & Test    │                                              │
│  │  ✓ Build Backend     │                                              │
│  │  ✓ Build Frontend    │                                              │
│  │  ✓ Run Unit Tests    │                                              │
│  │  ✓ Coverage Report   │                                              │
│  └──────────────────────┘                                              │
│           │                                                             │
│           ↓                                                             │
│  ┌──────────────────────┐                                              │
│  │  3. Docker Build     │                                              │
│  │  ✓ Backend Image     │                                              │
│  │  ✓ Frontend Image    │                                              │
│  │  ✓ Tag with SHA      │                                              │
│  └──────────────────────┘                                              │
│           │                                                             │
│           ↓                                                             │
│  ┌──────────────────────┐                                              │
│  │  4. Smoke Tests      │                                              │
│  │  ✓ Start Services    │                                              │
│  │  ✓ Health Checks     │                                              │
│  │  ✓ API Tests         │                                              │
│  └──────────────────────┘                                              │
│           │                                                             │
│           ↓                                                             │
│  ┌──────────────────────┐                                              │
│  │  5. Push to Registry │                                              │
│  │  ✓ GHCR Auth         │                                              │
│  │  ✓ Push Backend      │                                              │
│  │  ✓ Push Frontend     │                                              │
│  └──────────────────────┘                                              │
│           │                                                             │
│           ↓                                                             │
│  ┌──────────────────────┐                                              │
│  │  6. 🚀 DEPLOY (NEW)  │  ← TP4: Déploiement automatique             │
│  │  ✓ Stop Containers   │                                              │
│  │  ✓ Pull New Images   │                                              │
│  │  ✓ Start Services    │                                              │
│  │  ✓ Health Check      │                                              │
│  └──────────────────────┘                                              │
│           │                                                             │
│           ↓                                                             │
│  ┌──────────────────────┐                                              │
│  │  7. SonarCloud       │                                              │
│  │  ✓ Code Analysis     │                                              │
│  │  ✓ Coverage Report   │                                              │
│  │  ✓ Quality Gate      │                                              │
│  └──────────────────────┘                                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 🔄 Déploiement Local Automatisé (TP4)

Le projet implémente un **système de déploiement continu (CD)** entièrement automatisé qui s'exécute après chaque push validé sur la branche `main`.

#### **Comment ça fonctionne ?**

Le stage de déploiement est lancé **automatiquement** après la publication réussie des images Docker dans le registre (GHCR). Il exécute le script `scripts/deploy.sh` qui :

1. **Arrête proprement les conteneurs** en cours d'exécution
   ```bash
   docker compose down
   ```
   ⚠️ **Sans suppression des volumes** → Les données PostgreSQL sont préservées

2. **Récupère les dernières images** depuis le registre distant
   ```bash
   docker pull ghcr.io/<username>/cloudnativeapplicationcurse/backend:<sha>
   docker pull ghcr.io/<username>/cloudnativeapplicationcurse/frontend:<sha>
   ```

3. **Redémarre l'environnement complet**
   ```bash
   docker compose up -d
   ```

4. **Vérifie la santé** de l'application
   - Health check du backend
   - Vérification des services actifs
   - Affichage des logs en cas d'erreur

#### **Prérequis pour le déploiement automatique**

Pour que le déploiement automatique fonctionne, vous devez avoir :

✅ **Un runner GitHub Actions local actif**
   - Configuré avec `runs-on: self-hosted`
   - Doit avoir accès à Docker et Docker Compose
   
✅ **Secrets Docker configurés**
   - `GITHUB_TOKEN` : Token d'authentification GHCR (fourni automatiquement)
   - Le runner doit être authentifié au registre

✅ **Accès au registre distant**
   - Images disponibles sur `ghcr.io/<username>/<repo>/backend` et `frontend`
   - Permissions de lecture configurées correctement

✅ **Docker Compose fonctionnel**
   - Fichier `compose.yaml` à la racine du projet
   - Configuration réseau et volumes corrects

#### **Architecture du workflow CD**

```
build → test → lint → build images → push registry → 🚀 deploy
                                                        ↓
                                               ┌────────────────┐
                                               │ scripts/       │
                                               │ deploy.sh      │
                                               │                │
                                               │ • docker down  │
                                               │ • docker pull  │
                                               │ • docker up -d │
                                               │ • health check │
                                               └────────────────┘
```

#### **Branches avec déploiement automatique**

| Branche | Déploiement automatique | Condition |
|---------|-------------------------|-----------|
| `main` | ✅ **Actif** | Après push réussi et images publiées |
| `develop` | ❌ Désactivé | Tests uniquement |
| `feature/*` | ❌ Désactivé | Tests uniquement |

Le déploiement ne s'exécute **que sur la branche `main`** pour garantir que seules les versions validées sont déployées en production.

#### **Idempotence du déploiement**

Le script de déploiement est **idempotent** : vous pouvez l'exécuter plusieurs fois sans problème.

**Garanties :**
- ✅ Pas de perte de données (volumes préservés)
- ✅ Pas d'erreur si aucun conteneur n'est actif
- ✅ Gestion propre des échecs (logs affichés)
- ✅ Réexécutable sans intervention manuelle

#### **Exécution manuelle du déploiement**

Si besoin, vous pouvez lancer le déploiement manuellement :

```bash
# Rendre le script exécutable
chmod +x scripts/deploy.sh

# Définir les variables d'environnement
export GITHUB_SHA=latest
export IMAGE_NAME=mahkalix/cloudnativeapplicationcurse
export REGISTRY=ghcr.io

# Exécuter le déploiement
./scripts/deploy.sh
```

#### **Vérification post-déploiement**

Après un déploiement réussi, vérifiez :

```bash
# Services actifs
docker compose ps

# Logs en temps réel
docker compose logs -f

# Test manuel
curl http://localhost:3000/health
curl http://localhost
```

#### **Rollback en cas de problème**

Si le déploiement échoue ou si l'application ne fonctionne pas :

```bash
# Retour à la version précédente
docker compose down
docker pull ghcr.io/<username>/<repo>/backend:previous-sha
docker pull ghcr.io/<username>/<repo>/frontend:previous-sha
docker compose up -d
```

---

### 🔄 Workflow - Branches & PRs (TP1 + TP2)

#### **Branches**
| Branche | Rôle | Protection | Merge depuis |
|---------|------|-----------|--------------|
| `main` | Production | ✅ Protégée | `release/*` |
| `develop` | Développement | ✅ Protégée | `feature/*`, `hotfix/*` |
| `feature/<nom>` | Nouvelles fonctionnalités | ❌ | Depuis `develop` |
| `hotfix/<nom>` | Corrections urgentes | ❌ | Depuis `main` |
| `release/<version>` | Préparation de release | ❌ | Depuis `develop` |

#### **Workflow Git Flow**
```
main (v1.0.0)
  │
  ├─→ hotfix/urgent-bug
  │   └─→ PR hotfix → main
  │       └─→ Merge release → develop
  │
develop (v1.1.0-dev)
  │
  ├─→ feature/new-feature
  │   └─→ PR feature → develop
  │       └─→ CI/CD Pipeline ✓
  │           └─→ Code Review & Merge
  │
  ├─→ release/v1.1.0
  │   └─→ PR release → main
  │       └─→ Tag & Deploy
```

---

## Git Workflow & Commits

### ✔ Règles Git utilisées

- **Branches principales** : `main` (production), `develop` (staging)
- **Branches de feature** : `feature/<nom>` (issues/fonctionnalités)
- **Branches de hotfix** : `hotfix/<nom>` (corrections urgentes)
- **Branches de release** : `release/<version>` (préparation de release)
- **PR obligatoire** vers `develop` ou `main`
- **Pas de commit direct** sur `main` ou `develop`
- **Revue de code** obligatoire avant merge
- **CI/CD Pipeline** doit passer avec succès

### ✔ Convention de commit

Les commits doivent respecter la convention Conventional Commits :

**Types acceptés :**
- `feat:` - Nouvelle fonctionnalité
- `fix:` - Correction de bug
- `chore:` - Tâches de maintenance
- `docs:` - Documentation
- `style:` - Formatage du code
- `refactor:` - Refactorisation
- `perf:` - Amélioration de performance
- `test:` - Ajout/modification de tests
- `build:` - Changements du système de build
- `ci:` - Changements CI/CD
- `revert:` - Annulation d'un commit précédent

**Format recommandé :**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Exemples :**
```bash
feat: ajout de l'authentification
feat(auth): intégration OAuth2
fix: correction de la connexion Postgres
fix(booking): gestion des conflits horaires
chore: mise à jour des dépendances
docs: mise à jour du README
test: ajout des tests d'intégration
ci: configuration GitHub Actions
```

### ✔ Hooks actifs (Husky)

- **`pre-commit`** : Exécute le lint du frontend et du backend avant chaque commit
- **`commit-msg`** : Vérifie que le message de commit respecte la convention avec commitlint

Les commits non conformes seront **automatiquement rejetés**.

### ✔ Protection des branches

| Règle | `main` | `develop` | `feature/*` |
|-------|--------|-----------|-----------|
| Require PR reviews | ✅ 2 approvals | ✅ 1 approval | ❌ |
| Dismiss stale reviews | ✅ | ✅ | N/A |
| Require status checks | ✅ CI/CD | ✅ CI/CD | ❌ |
| Lock branch | ⏱️ Avant release | ❌ | ❌ |
| Allow force push | ❌ | ❌ | ✅ |

### ✔ Processus de merge

1. **Créer une feature branch** depuis `develop`
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/ma-feature
   ```

2. **Développer avec commits conventionnels**
   ```bash
   git add .
   git commit -m "feat: description de la feature"
   ```

3. **Push et créer une PR**
   ```bash
   git push origin feature/ma-feature
   # Créer la PR vers develop sur GitHub
   ```

4. **Attendre la validation**
   - ✅ CI/CD Pipeline passe
   - ✅ Code Review approuvé
   - ✅ Tous les checks passent

5. **Merger dans develop**
   ```bash
   # Merge via GitHub (Squash or Regular Merge)
   ```

6. **Supprimer la branche**
   ```bash
   git branch -d feature/ma-feature
   git push origin --delete feature/ma-feature
   ```

## Contributing

1. Fork the repository
2. Create a feature branch (`feature/<name>`)
3. Make your changes
4. Ensure your commits follow the conventional commit format
5. Push to your branch
6. Submit a pull request to `develop`

## License

This project is licensed under the MIT License.

## Support

For support or questions, please open an issue in the repository.
