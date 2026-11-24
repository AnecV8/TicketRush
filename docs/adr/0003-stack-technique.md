# ADR 0003 — Java Spring Boot pour les services, React pour le frontend

Statut : Proposé

Date : 2026-11-24

Scénario(s) de qualité concerné(s) : Q2, Q5, Q8, Q10, Q11

## Contexte
TicketRush compte quatre modules (catalogue, file d'attente, réservation et paiement, analytique temps réel), développés par trois personnes en parallèle.
Chaque service doit publier et consommer des événements Kafka via Redpanda ([ADR 0001](0001-broker-evenements.md)) et être instrumenté avec OpenTelemetry ([ADR 0002](0002-stack-observabilite.md)), selon les règles de la [section 8](../arc42/08-concepts-transverses.md).
Pendant le pic, le service de réservation doit répondre en moins d'une seconde au p95 (Q2), et une panne injectée doit être diagnostiquée en moins d'une minute (Q8).
On doit pouvoir ajouter un consommateur sans toucher aux producteurs (Q10), ce qui demande de vérifier les dépendances automatiquement, et lancer le projet en une seule commande (Q11).
Les trois membres connaissent Java et React.

## Décision
Les services backend sont écrits en Java 21 (LTS) avec Spring Boot, un projet par module, tous construits à partir d'un même gabarit de service.
Le frontend (parcours acheteur et tableau de bord de l'organisateur) est une application React, construite avec Vite et servie comme un conteneur à part.

## Alternatives écartées
- Node.js (NestJS) : bon support de Kafka et d'OpenTelemetry, mais l'instrumentation automatique couvre moins de bibliothèques, et l'équipe a moins de pratique de TypeScript côté serveur.
- Go : léger et rapide à démarrer, mais nouveau pour l'équipe, et l'instrumentation OpenTelemetry s'y fait à la main, service par service.
- Quarkus ou Micronaut : Java aussi, démarrage plus rapide et mémoire réduite, mais moins de documentation et d'exemples pour Spring Kafka, l'outbox et Keycloak, ce qui coûte du temps à une équipe de trois.
- Rendu côté serveur (Thymeleaf) à la place de React : un composant de moins, mais un tableau de bord temps réel qui se met à jour sans recharger la page est plus simple à faire dans une application React.

## Conséquences
- **+** L'agent Java OpenTelemetry instrumente HTTP, JDBC et les clients Kafka sans code : il suffit d'ajouter `-javaagent` dans l'image du service. Il se configure uniquement par les variables `OTEL_*` de la [section 8](../arc42/08-concepts-transverses.md) et propage `traceparent` dans les en-têtes Kafka, ce qui sert le diagnostic (Q8).
- **+** ArchUnit permet d'écrire la fonction de fitness sur les dépendances comme un simple test JUnit, lancé en CI : par exemple, aucun service ne dépend du code d'un autre contexte, et le domaine ne dépend pas de l'infrastructure (Q10).
- **+** Un gabarit de service Spring Boot (dépendances, Dockerfile avec l'agent, variables `OTEL_*`, healthcheck, test ArchUnit) peut être copié par chaque membre : les services suivent les mêmes conventions, et chacun démarre de la même façon dans Docker Compose (Q11).
- **+** Spring Security sert de serveur de ressources OAuth2 relié à Keycloak : une requête sans jeton valide est refusée en 401 (Q5).
- **+** Java 21 apporte les threads virtuels : beaucoup de requêtes simultanées en attente de la base ou de Redis, sans grossir un pool de threads (Q2).
- **−** Une JVM par service consomme plus de mémoire et démarre plus lentement qu'un binaire Go, sur un poste qui fait aussi tourner k6 : il faut limiter la mémoire de chaque conteneur et surveiller le temps de démarrage, qui compte dans la reprise en moins de 30 s (Q7).
- **−** L'agent OpenTelemetry ajoute quelques secondes au démarrage, et il ne voit pas l'outbox : le relais doit relire le `traceparent` enregistré avec le message et le remettre dans le contexte, à la main.
- **−** Deux chaînes de build (Maven pour les services, npm pour le frontend) à maintenir dans la CI.