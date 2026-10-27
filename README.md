# TicketRush

Projet d'architecture logicielle, ESGI M1, en trinôme.

## Lancer
docker compose up -d

- Grafana : http://localhost:3000
- Keycloak : http://localhost:8180 (admin / admin)

## Organisation
- `docs/adr/` : décisions d'architecture 
- `docs/c4/` : diagrammes C4 en Structurizr DSL
- `docs/arc42/` : dossier d'architecture
- `src/` : code
- `load-tests/` : scripts k6

## Règles
- Pas de push direct sur `main` : une branche, puis une pull request relue par un autre membre.
- Un ADR par décision importante.