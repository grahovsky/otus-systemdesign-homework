# arc42 §5 — Building Block View

Раздел реализован как LikeC4-модель в [`../architecture/`](../architecture/).

## Level 1 — System Context (C1)

Чёрный ящик Bookly + акторы + внешние системы.

- View: [`../architecture/views/c1-context.c4`](../architecture/views/c1-context.c4) (`bookly-c1`)
- Система: [`../architecture/model/booking/index.c4`](../architecture/model/booking/index.c4)

## Level 2 — Containers (C2)

Сервисы, Kafka, хранилища, протоколы на рёбрах.

- View: [`../architecture/views/c2-containers.c4`](../architecture/views/c2-containers.c4) (`bookly-c2`)
- Связи: [`../architecture/model/relations-core.c4`](../architecture/model/relations-core.c4)

### Сервисы (кратко)

| Контейнер | Роль |
|---|---|
| API Gateway | Edge: REST/GraphQL → gRPC |
| Identity | JWT, профили |
| Catalog | Контент и тарифы |
| Search | CQRS read-model (OpenSearch) |
| Inventory | Слоты, holds |
| Booking | Агрегат + Saga |
| Payment | Деньги + webhooks |
| Notification | Email/SMS consumer |

C3 / env-views / ER на этапе ДЗ 2 не ведутся.

## Как посмотреть

```bash
cd hw_02/solution/architecture
npx --yes likec4@1 dev
```
