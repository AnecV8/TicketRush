# ADR 0002 — OpenTelemetry et l'image grafana/otel-lgtm pour l'observabilité

Statut : Proposé

Date : 2026-11-24

Scénario(s) de qualité concerné(s) : Q7, Q8

## Contexte
Le projet exige des traces distribuées, des métriques et des journaux (OpenTelemetry), un tableau de bord de la mise en vente et des SLO mesurés.
Pendant la soutenance, le comité injecte une panne : on doit voir en moins d'une minute quel service est en cause (Q8) et que la vente reprend (Q7).
L'équipe est de trois personnes ; le temps passé à configurer l'outillage n'est pas passé sur les modules.

## Décision
Les services sont instrumentés avec OpenTelemetry et envoient tout en OTLP (ports 4317 et 4318).
En local, on utilise l'image grafana/otel-lgtm, qui réunit en un seul conteneur le collecteur OpenTelemetry, Prometheus (métriques), Tempo (traces), Loki (journaux) et Grafana.
Les tableaux de bord sont versionnés dans le dépôt et chargés au démarrage.

## Alternatives écartées
- Les cinq composants déployés séparément : plus proche de la production, mais beaucoup plus de configuration pour le même résultat en démonstration.
- Jaeger + Prometheus : couvre les traces et les métriques, mais pas les journaux, et demande d'assembler plusieurs interfaces.
- Stack Elastic (ELK) : lourde en mémoire, peu adaptée à un poste qui lance aussi le test de charge.
- Service SaaS (Datadog, Grafana Cloud) : compte et coût, dépendance au réseau pendant la soutenance, et données envoyées hors du poste.

## Conséquences
- **+** Une seule ligne dans Docker Compose pour les trois signaux, corrélés dans Grafana (d'une trace à ses journaux).
- **+** OTLP est un standard : changer de backend ne touche pas au code des services.
- **+** Si l'observabilité tombe, la vente continue : c'est un composant hors du chemin critique.
- **-** Image conçue pour le développement : pas de persistance configurée ici, les données disparaissent au redémarrage. D'où les tableaux de bord dans le dépôt.
- **-** Un seul conteneur, sans mise à l'échelle : en production, on séparerait les composants (voir la vue de déploiement).
- **-** À 50 000 acheteurs virtuels, garder toutes les traces surchargerait le conteneur : il faudra échantillonner les traces pendant le test de charge.