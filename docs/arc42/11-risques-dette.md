# 11. Risques et dette technique

## Risques

## Registre de la dette technique

Chaque dette est classée selon le quadrant de Fowler :

|                | Délibérée                                          | Involontaire                                           |
|----------------|----------------------------------------------------|--------------------------------------------------------|
| **Prudente**   | On connaît le raccourci et on le paiera plus tard. | On a compris après coup comment il aurait fallu faire. |
| **Imprudente** | On choisit de ne pas bien faire, faute de temps.   | On ne savait pas que c'était un problème.              |

Règles :

- Toute PR qui introduit un raccourci connu ajoute une ligne à ce registre.
- Une dette remboursée n'est pas supprimée : elle passe en « Remboursée » avec le lien vers la PR qui la corrige.
- La colonne « Coût » décrit l'intérêt payé tant que la dette reste ouverte.
- Le remboursement est déclenché par un événement du projet plutôt que par une date.

| #  | Dette                                                                                 | Type (quadrant de Fowler) | Coût                                                                                                                                     | Remboursement prévu                                                                                                                          | Statut          |
|----|---------------------------------------------------------------------------------------|---------------------------|------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|-----------------|
| D1 | Mots de passe en clair dans `docker-compose.yml` (PostgreSQL, admin Keycloak)         | Prudente, délibérée       | Fuite si le fichier sert de base à un déploiement réel ; changer un secret impose de modifier le dépôt                                   | Fichier `.env` non versionné et `.env.example` versionné, avant tout déploiement hors poste local                                            | Ouverte         |
| D2 | Keycloak en mode `start-dev` : base H2 interne, realm configuré à la main             | Prudente, délibérée       | Realm, clients et utilisateurs de test perdus à chaque recréation du conteneur ; configuration non relue en revue                        | Exporter le realm en JSON dans le dépôt et l'importer au démarrage (`--import-realm`), dès la mise en place de l'authentification            | Ouverte         |
| D3 | Observabilité sans persistance (`grafana/otel-lgtm`, voir ADR 0002)                   | Prudente, délibérée       | Traces, métriques et logs perdus au redémarrage : un test k6 doit être analysé avant d'arrêter la stack                                  | Exporter les résultats utiles au post-mortem après chaque test de charge ; volumes ou composants séparés si un historique devient nécessaire | Ouverte         |
| D4 | Redpanda à un seul nœud (`--mode=dev-container`, `--smp=1`, voir ADR 0001)            | Prudente, délibérée       | Aucune réplication : la perte du broker arrête les échanges d'événements, et les scénarios de panne du broker ne sont pas représentatifs | Décrire la cible (3 nœuds, facteur de réplication 3) dans la section 7 ; cluster multi-nœuds seulement si un scénario de qualité l'exige     | Ouverte         |
| D5 | Keycloak et otel-lgtm sans healthcheck, absents du test de démarrage en CI            | Prudente, délibérée       | Une régression sur ces services n'est détectée qu'au lancement manuel                                                                    | Ajouter un healthcheck et les inclure au job « Infrastructure » dès qu'un service applicatif en dépend                                       | Ouverte         |
| D6 | Images Docker et actions GitHub épinglées par tag, sans mise à jour automatique       | Prudente, délibérée       | Les correctifs de sécurité ne sont pas appliqués d'eux-mêmes ; un tag peut être republié avec un autre contenu                           | Activer Dependabot (ou Renovate) sur `docker-compose.yml` et `.github/workflows/`                                                            | Ouverte         |
| D7 | Redpanda annonçait `127.0.0.1:9092` : broker injoignable depuis les autres conteneurs | Imprudente, involontaire  | Aurait bloqué toute communication par événements entre services                                                                          | Listeners interne (`redpanda:9092`) et externe (`localhost:19092`), vérifiés automatiquement en CI                                           | Remboursée (#4) |
| D8 | Keycloak 25 ignorait `KC_BOOTSTRAP_ADMIN_*` : aucun compte administrateur             | Imprudente, involontaire  | Console d'administration inaccessible                                                                                                    | Passage à Keycloak 26.0                                                                                                                      | Remboursée (#4) |