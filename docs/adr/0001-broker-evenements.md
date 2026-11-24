# ADR 0001 — Redpanda comme bus d'événements

Statut : Proposé

Date : 2026-11-24

Scénario(s) de qualité concerné(s) : Q3, Q7, Q8

## Contexte
La réservation, le paiement et l'émission du billet passent par une saga : les services échangent des événements au lieu de s'appeler en direct, pour qu'une panne du prestataire de paiement (Q3) ou d'une instance (Q7) ne bloque pas toute la vente.
Ces événements sont publiés via le pattern Outbox, donc au moins une fois : les consommateurs doivent être idempotents.
L'analytique temps réel doit relire le flux des ventes, et le rejouer après une panne ou pour reconstruire un tableau de bord.
Pendant le test de charge, le broker tourne sur le même poste que 50 000 acheteurs virtuels k6.

## Décision
On utilise Redpanda, un broker compatible avec le protocole Kafka, déployé en un seul conteneur.
Les services l'utilisent via des clients Kafka standards, sans dépendance à Redpanda.

## Alternatives écartées
- Apache Kafka (mode KRaft) : même protocole et référence du cours, mais une JVM plus gourmande en mémoire et plus lente à démarrer en local, pendant le test de charge.
- RabbitMQ : une file de messages, pas un journal ; un message consommé disparaît, donc pas de rejeu pour l'analytique.
- Redis Streams : évite un composant de plus, mais Redis sert déjà la file d'attente et les blocages de places au pic ; y ajouter le bus d'événements concentre la charge et la panne sur un seul composant, et les outils de traitement de flux sont plus pauvres.

## Conséquences
- **+** Un journal durable et rejouable : saga, outbox et analytique s'appuient sur le même flux.
- **+** Léger en local : il laisse les ressources du poste au test de charge.
- **+** Protocole Kafka : passer à Apache Kafka ne change que l'infrastructure, pas le code des services.
- **-** Un composant de plus à exploiter et à superviser.
- **-** Écosystème plus petit que Kafka, et une licence source-available (BSL), sans conséquence pour un projet d'école.
- **-** Livraison au moins une fois : chaque consommateur garde la trace des messages déjà traités.