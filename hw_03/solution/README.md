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

_Тип БД для каждого сервиса с обоснованием (таблица)._

## 3. Шардирование

_Схема шардирования для 1–2 ключевых сервисов и выбор ключа._

## 4. Кэширование

_Что кэшируем, стратегия, TTL._

## 5. Очереди

_Где брокер сообщений, какой и почему._

## 6. CAP trade-offs

_Как решение соотносится с CAP-теоремой._
