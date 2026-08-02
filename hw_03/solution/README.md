# ДЗ 3. Проектирование хранения данных — решение

> Условие: [../Задание.md](../Задание.md)
> Шаблоны: [сравнение БД](../Таблица%20сравнения%20БД%20с%20критериями%20выбора.md) ·
> [кэширование](../Чек-лист%20стратегий%20кэширования.md) ·
> [шардирование](../Шаблон%20схемы%20шардирования.md). Схемы — в [diagrams/](diagrams/).

> Система: **Bookly** (сервис бронирования) — продолжение [ДЗ 2](../../hw_02/solution/).

---

## 1. Модель данных

Схема: [`diagrams/er-data-model.puml`](diagrams/er-data-model.puml).

| Сервис | Хранилище | Что хранит |
|---|---|---|
| Identity | PostgreSQL | `users` (email, hash, role) |
| Catalog | PostgreSQL | `properties`, `room_types`, `rate_plans` + **outbox** → `catalog.updated` |
| Inventory | PostgreSQL | `availability_slots`, `holds` + **outbox** → `inventory.*` |
| Booking | PostgreSQL | `bookings` (статус саги + snapshot цены) + **outbox** → `booking.*` |
| Payment | PostgreSQL | `payment_intents`, `idempotency_keys`, `webhook_log` + **outbox** → `payment.*` |
| Search | OpenSearch | денормализованный `property_doc` (гео, фильтры, minPrice, availabilityHints) |
| Notification | — | шаблоны в конфиге; своей БД нет (delivery-log опционален, не SoT) |
| Gateway | — | без БД; rate-limit counters в Redis |

Инварианты:

- **Available** = `allotment_total − allotment_sold − count(active holds)`. Soft-hold не дублируется в `slots`.
- Outbox у **всех writers** (Catalog, Inventory, Booking, Payment) — публикация в Kafka после commit.
- Search — CQRS read-model, **не** source of truth доступности ([ADR-0004](../../hw_02/solution/arc42/adr/0004-cqrs-search.md)).


## 2. Выбор БД

| Сервис | Что хранит | Форма данных | Ключевые запросы | Выбранная БД | Почему |
|---|---|---|---|---|---|
| Identity | аккаунты, роли | реляционная | login по email, validate JWT claims | **PostgreSQL** | уникальность email, ACID на credentials; объём маленький |
| Catalog | объекты, room types, тарифы | реляционная + JSONB policy | CRUD партнёра, snapshot цены по id | **PostgreSQL** | связи property→room→rate, транзакция при обновлении тарифа |
| Inventory | слоты, holds | реляционная | Hold/Confirm/Release в транзакции по property | **PostgreSQL** | ACID против overbooking; ≠ Cassandra/Dynamo — там нет надёжного multi-row hold на диапазон дат |
| Booking | бронь + saga state | реляционная | create/cancel, status, outbox | **PostgreSQL** | статус саги + outbox в **одной** транзакции; документная БД хуже для outbox-паттерна |
| Payment | intents, idempotency, webhooks | реляционная | create/capture/refund, дедуп webhook | **PostgreSQL** | идемпотентность + аудит; ≠ чистый KV — нужны вторичные ключи и история |
| Search | read-model выдачи | документ + инверт. индекс | гео, фильтры, сортировка, пагинация | **OpenSearch** | паттерн доступа ≠ SQL; жертва: JOIN/ACID → eventual OK ([ADR-0004](../../hw_02/solution/arc42/adr/0004-cqrs-search.md)) |
| (infra) Redis | кэш, rate-limit, hold TTL index | key-value + TTL | GET/SET по ключу | **Redis** | не primary store; SoT hold = Postgres ([ADR-0003](../../hw_02/solution/arc42/adr/0003-inventory-soft-hold.md)) |
| Notification | — | — | consume events | нет БД | stateless consumer; retry через Kafka offset |

5× PostgreSQL — не «по умолчанию»: у каждого своя причина ACID/связей. Разные семейства — OpenSearch (поиск) и Redis (кэш/TTL).

---

## 3. Шардирование

_Схема шардирования для 1–2 ключевых сервисов и выбор ключа._

## 4. Кэширование

_Что кэшируем, стратегия, TTL._

## 5. Очереди

_Где брокер сообщений, какой и почему._

## 6. CAP trade-offs

_Как решение соотносится с CAP-теоремой._
