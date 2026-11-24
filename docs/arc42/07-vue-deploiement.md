# 7. Vue de déploiement

TicketRush tourne aujourd'hui dans deux environnements : le poste de développement et la CI. Une cible de production est décrite à titre d'hypothèse ; elle n'est pas déployée.

## 7.1 Environnement local

Toute l'infrastructure est décrite dans [`docker-compose.yml`](../../docker-compose.yml) et se lance en une commande. Les services applicatifs (catalogue, file d'attente, réservation, analytique) y seront ajoutés comme conteneurs supplémentaires.

| Service         | Image                            | Rôle                                                                  | Port(s) hôte     | Healthcheck          | Persistance                  |
|-----------------|----------------------------------|-----------------------------------------------------------------------|------------------|----------------------|------------------------------|
| `postgres`      | `postgres:16.4`                  | Base relationnelle                                                    | 5432             | `pg_isready`         | Volume nommé `postgres-data` |
| `redis`         | `redis:7.4`                      | Stockage en mémoire, usage précisé par les ADR des modules            | 6379             | `redis-cli ping`     | Aucune                       |
| `redpanda`      | `redpandadata/redpanda:v24.2.7`  | Bus d'événements compatible Kafka (ADR 0001)                          | 19092            | `rpk cluster health` | Aucune                       |
| `keycloak`      | `quay.io/keycloak/keycloak:26.0` | Fournisseur d'identité (OIDC)                                         | 8180             | Aucun                | Aucune (base H2 interne)     |
| `observabilite` | `grafana/otel-lgtm:0.8.1`        | Collecteur OpenTelemetry, Prometheus, Tempo, Loki, Grafana (ADR 0002) | 3000, 4317, 4318 | Aucun                | Aucune                       |

## 7.2 Réseau

Tous les services partagent le réseau par défaut de Docker Compose et se joignent par leur nom de service.

Redpanda expose deux adresses, car un client Kafka se reconnecte à l'adresse que le broker lui annonce, pas à celle qu'il a utilisée au départ :

| Client                      | Adresse à utiliser | Annoncée par le listener |
|-----------------------------|--------------------|--------------------------|
| Conteneur du réseau Compose | `redpanda:9092`    | `internal`               |
| Poste hôte (outil, test k6) | `localhost:19092`  | `external`               |

Les autres adresses utiles :

| Usage                           | Depuis un conteneur  | Depuis l'hôte           |
|---------------------------------|----------------------|-------------------------|
| Envoi de télémétrie OTLP (gRPC) | `observabilite:4317` | `localhost:4317`        |
| Envoi de télémétrie OTLP (HTTP) | `observabilite:4318` | `localhost:4318`        |
| Grafana                         | —                    | `http://localhost:3000` |
| Console Keycloak                | `keycloak:8080`      | `http://localhost:8180` |

Keycloak est publié sur le port 8180 pour laisser le port 8080 libre aux services applicatifs.

## 7.3 Commandes

| Action                                             | Commande                        |
|----------------------------------------------------|---------------------------------|
| Télécharger les images (premier lancement)         | `docker compose pull`           |
| Démarrer et attendre que les services soient prêts | `docker compose up -d --wait`   |
| Voir l'état des services                           | `docker compose ps`             |
| Lire les logs d'un service                         | `docker compose logs <service>` |
| Arrêter en gardant les données                     | `docker compose down`           |
| Arrêter et effacer les données PostgreSQL          | `docker compose down -v`        |

`--wait` attend l'état `healthy` pour les services qui ont un healthcheck, et seulement l'état `running` pour Keycloak et l'observabilité.

## 7.4 Environnement de CI

La CI (GitHub Actions, `.github/workflows/ci.yml`) tourne sur un runner `ubuntu-latest` et démarre uniquement PostgreSQL, Redis et Redpanda. Elle vérifie qu'ils passent `healthy` et que Redpanda annonce bien `localhost:19092` à l'extérieur, puis supprime les conteneurs et les volumes.

Keycloak et l'observabilité ne sont pas démarrés en CI : images lourdes, pas de healthcheck, et aucun service n'en dépend encore (dette D5).