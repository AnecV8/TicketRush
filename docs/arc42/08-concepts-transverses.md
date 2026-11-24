# 8. Concepts transverses

Règles communes à tous les services, quel que soit le module ou le langage.

## Observabilité

Les services sont instrumentés avec OpenTelemetry et envoient traces, métriques et journaux en OTLP vers le conteneur `observabilite` ([ADR 0002](../adr/0002-stack-observabilite.md)).

### Configuration

Chaque service est configuré uniquement par les variables d'environnement standard d'OpenTelemetry, sans adresse écrite dans le code :

| Variable | Valeur locale | Rôle |
|---|---|---|
| `OTEL_SERVICE_NAME` | Nom du module en kebab-case, par exemple `reservation` | Identifie le service dans Grafana |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://observabilite:4317` | Adresse du collecteur (voir la [vue de déploiement](07-vue-deploiement.md)) |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` | Protocole d'envoi |
| `OTEL_RESOURCE_ATTRIBUTES` | `deployment.environment.name=local` | Distingue local, CI et test de charge |
| `OTEL_TRACES_SAMPLER` | `parentbased_traceidratio` | Respecte la décision du service appelant |
| `OTEL_TRACES_SAMPLER_ARG` | `1.0` en local, `0.1` pendant le test de charge | Part des traces conservées |

L'échantillonnage à 10 % pendant le test de charge évite de saturer le conteneur d'observabilité avec 50 000 acheteurs virtuels. Les métriques, elles, ne sont pas échantillonnées : les SLO restent exacts.

### Traces

- Le contexte de trace est propagé au format W3C Trace Context (en-tête `traceparent`).
- Entre services HTTP, l'en-tête est transmis tel quel.
- Dans Redpanda, `traceparent` est copié dans les en-têtes du message. Le consommateur reprend la trace là où le producteur l'a laissée : une réservation reste visible de bout en bout, même quand elle passe par le bus.
- Un message écrit d'abord dans une table d'outbox garde son `traceparent` avec lui, pour que la trace ne soit pas coupée par le relais.

### Métriques

- Les métriques HTTP suivent les conventions sémantiques d'OpenTelemetry (par exemple `http.server.request.duration`) : le SDK les produit sans code supplémentaire.
- Les métriques métier sont préfixées par `ticketrush.`, en minuscules, séparées par des points, par exemple `ticketrush.reservations.confirmed`. Dans Prometheus, les points deviennent des soulignés et les compteurs prennent le suffixe `_total` : `ticketrush_reservations_confirmed_total`.
- Aucun identifiant d'utilisateur, de place ou de réservation n'est utilisé comme attribut de métrique : chaque valeur distincte crée une nouvelle série, et 50 000 acheteurs feraient tomber Prometheus. Ces identifiants vont dans les traces et les journaux.

### Journaux

- Les journaux sont structurés (une entrée = un objet avec des champs), envoyés en OTLP et écrits aussi sur la sortie standard pour `docker compose logs`.
- Chaque entrée porte le `trace_id` et le `span_id` courants : depuis une trace dans Grafana, on retrouve ses journaux, et inversement.
- Niveaux : `ERROR` quand une action échoue et demande une intervention, `WARN` quand le service se rétablit seul (nouvel essai, valeur par défaut), `INFO` pour les étapes métier, `DEBUG` désactivé par défaut.
- Aucun secret, mot de passe, jeton ou donnée de paiement n'apparaît dans un journal, une trace ou un attribut.

### Tableaux de bord

Les tableaux de bord Grafana sont versionnés dans le dépôt et chargés au démarrage : ils survivent à la perte des données d'observabilité (dette D3 du [registre](11-risques-dette.md)).

## Événements

Les services échangent des événements par Redpanda ([ADR 0001](../adr/0001-broker-evenements.md)).

### Nommage

- Un événement décrit un fait passé, au passé, dans le langage du domaine (voir le glossaire) : `PlaceReservee`, `PaiementEchoue`.
- Un topic par contexte, nommé `<contexte>.evenements`, par exemple `reservation.evenements`.
- La clé du message est l'identifiant de l'agrégat concerné : tous les événements d'un même agrégat arrivent dans la même partition, donc dans l'ordre.

### Enveloppe

Tous les événements ont la même enveloppe JSON, inspirée de CloudEvents :

```json
{
  "id": "0d6f3c1e-7b8a-4c51-9a3e-2f1b6d4e8c90",
  "type": "PlaceReservee",
  "version": 1,
  "source": "reservation",
  "time": "2026-11-24T18:00:00.123Z",
  "data": { }
}
```

| Champ | Contenu |
|---|---|
| `id` | UUID unique de l'événement, utilisé pour éliminer les doublons |
| `type` | Nom de l'événement |
| `version` | Version du schéma de `data`, entier commençant à 1 |
| `source` | Service émetteur, identique à `OTEL_SERVICE_NAME` |
| `time` | Moment du fait métier, en UTC |
| `data` | Contenu propre à l'événement |

### Évolution des schémas

- Un schéma n'évolue qu'en ajoutant des champs optionnels : les consommateurs existants continuent de fonctionner.
- Un consommateur ignore les champs qu'il ne connaît pas.
- Supprimer, renommer ou changer le type d'un champ est un changement incompatible : il passe par une nouvelle `version`, et l'ancienne reste publiée tant qu'un consommateur l'utilise.

Ces règles sont vérifiées automatiquement par une fonction de fitness sur la compatibilité des contrats.

## Configuration et conventions communes

- Toute configuration passe par des variables d'environnement : le même code tourne en local, en CI et en test de charge. Les valeurs locales sont dans `docker-compose.yml`, les secrets en sortiront (dette D1).
- Les dates et heures sont stockées et échangées en UTC, au format ISO 8601 (`2026-11-24T18:00:00.123Z`). La conversion en heure locale ne se fait qu'à l'affichage.
- Les identifiants exposés hors d'un service sont des UUID : ils peuvent être créés sans consulter la base, et ne révèlent ni volume ni ordre.
- Les noms de services, de topics et de métriques sont en minuscules, sans accent.

## Sécurité

## Idempotence et gestion des erreurs

### Consommation des événements

Un consommateur valide son offset seulement après avoir traité le message : si le service tombe entre les deux, le message est relu au redémarrage. La livraison est donc « au moins une fois », et un même événement peut arriver deux fois.

Tout consommateur doit être idempotent : il garde la trace des `id` déjà traités et ignore un événement déjà vu. Traiter deux fois `PlaceReservee` ne doit ni compter deux réservations ni fausser l'analytique.