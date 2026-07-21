# ДЗ 2. Проектирование взаимодействия сервисов — решение

> Условие: [../Задание.md](../Задание.md) · Таблица протоколов: [../Таблица протоколов.md](../Таблица%20протоколов.md)
> Схемы: [architecture/](architecture/) (LikeC4) · stub: [diagrams/](diagrams/)

## Выбранная система

**Сервис бронирования (Bookly)** — аналог Booking.com: поиск, soft-hold инвентаря, оплата, отмены.

Формат документации — LikeC4 (C1/C2) + arc42 §1/§4/§5/§9 + ADR.
ER/PlantUML - для моделей данных (hw_03)

| Раздел | Путь |
|---|---|
| LikeC4 C1/C2 | [`architecture/`](architecture/) |
| arc42 | [`arc42/`](arc42/) |

---

## 1. Декомпозиция

8 сервисов — см. [arc42 §4](arc42/04-solution-strategy.md#41-декомпозиция-8-сервисов) и C2.

| Сервис | Ответственность |
|---|---|
| API Gateway | Edge, auth, REST/GraphQL → gRPC |
| Identity | Аккаунты, JWT, роли |
| Catalog | Объекты, room types, тарифы |
| Search | CQRS read-model (гео/фильтры) |
| Inventory | Аллотмент, soft-hold TTL, confirm/release |
| Booking | Агрегат брони + оркестратор Saga |
| Payment | PaymentIntent, confirm/refund, idempotency, webhooks |
| Notification | Email/SMS по событиям |

---

## 2. Протоколы

Микс с обоснованием: [§4.3](arc42/04-solution-strategy.md#42-протоколы-микс), [ADR-0001](arc42/adr/0001-protocol-mix.md).

- **REST** — публичные команды (book/pay/cancel)
- **GraphQL** — поиск под разные клиенты
- **gRPC** — sync между сервисами (hold, authorize)
- **Kafka** — факты, проекции Search, уведомления
- **REST webhooks** — Payment Provider

---

## 3. Схема взаимодействия

- C1: [`architecture/views/c1-context.c4`](architecture/views/c1-context.c4) (`bookly-c1`)
- C2 (протоколы на рёбрах): [`architecture/views/c2-containers.c4`](architecture/views/c2-containers.c4) (`bookly-c2`)

---

## 4. API-контракты

Ключевые API: [`api/`](api/)

1. Search (GraphQL)
2. Create Booking (REST)
3. Payment + webhook (REST)
4. Cancel Booking (REST)

---

## 5. Асинхронность

Где и почему — [§4.4](arc42/04-solution-strategy.md#44-асинхронность--где-и-зачем).

Кратко: sync на hold + CreateIntent (гость ждёт); async на Search-проекцию, email/SMS,
TTL-expire (`inventory.released`) и webhook `payment.captured` → Confirm.

---

## 6. Паттерны

| Паттерн | ADR / § |
|---|---|
| Saga (orchestration) | [ADR-0002](arc42/adr/0002-saga-orchestration.md) |
| Soft-hold + TTL | [ADR-0003](arc42/adr/0003-inventory-soft-hold.md) |
| CQRS (Search) | [ADR-0004](arc42/adr/0004-cqrs-search.md) |
| Idempotency keys | [ADR-0005](arc42/adr/0005-payment-idempotency.md) |
| Outbox, API Gateway | [§4.5](arc42/04-solution-strategy.md#45-паттерны) |