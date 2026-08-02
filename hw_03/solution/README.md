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

Инварианты выбора (что **не** ставим вместо Postgres на SoT сейчас):

- **MongoDB / документные** не заменяют Inventory / Booking / Payment / Identity: нужен multi-row ACID (hold на диапазон дат, saga+outbox, идемпотентность+аудит). Для Catalog документ «property целиком» выглядит заманчиво, но частичные апдейты тарифов/room types + транзакции проще в Postgres (+ JSONB на policy) — Mongo не даёт выигрыша, только операционную сложность ещё одной СУБД.
- **ClickHouse / колоночные** — не OLTP: точечные `UPDATE` hold/confirm, низкая латентность записи и строгие инварианты — антипаттерн. ClickHouse уместен **позже** как OLAP-sink (ETL из Kafka: occupancy, воронка брони, отчёты партнёру), **не** как primary store сервисов.
- **NewSQL** (CockroachDB, Spanner, Yugabyte; VoltDB — узкий in-memory) теоретически снимает ручное шардирование Inventory/Booking: SQL + распределённый ACID. На старте **не берём**: выше write-latency (consensus/Paxos/Raft), ops/стоимость, другая семантика транзакций и миграционный риск. Ручной shard key в Postgres — осознанный контроль locality hold’ов. NewSQL — эскалация, когда app-level sharding станет дороже эксплуатации, чем смена СУБД (и только для сервисов с горизонтальным write-path, не «везде»).
- Итого: альтернативы семейств уже заняты задачей (OpenSearch = поиск, Redis = кэш/TTL); документные/колоночные/NewSQL на write-path SoT сейчас не используем.

---

## 3. Шардирование

Схемы: [`sharding-inventory.puml`](diagrams/sharding-inventory.puml), [`sharding-booking.puml`](diagrams/sharding-booking.puml).

### Шаг 0. Нужно ли?

Предварительная оценка:

- Inventory: `properties × room_types × горизонт_дат` — миллионы–десятки млн строк слотов + пиковый RPS hold на популярные даты.
- Booking: история броней растёт линейно с DAU × конверсия; «мои брони» — частый read.

Вертикаль + read-реплики на старте хватает, но горизонт роста упирается именно сюда → проектируем шардирование **заранее** для Inventory и Booking.

**Не шардируем на старте:** Identity (мало данных), Catalog (умеренный объём, низкий write RPS), Payment (сильная консистентность и аудит проще на одной primary; scale later через партиции по времени при необходимости).

### Кандидаты в ключи

**Inventory**

| Кандидат | Равномерность | Локальность | Hotspot | Вывод |
|---|---|---|---|---|
| `property_id` | высокая | Hold/Confirm/Release в одном шарде | популярный отель | **берём** |
| `room_type_id` | выше дробление | hold на диапазон всё равно в property | слабее | не нужен как основной ключ |
| `date` | плохая (пик «сегодня+каникулы») | ломает транзакцию hold | сильный | нет |

**Booking**

| Кандидат | Равномерность | Локальность | Hotspot | Вывод |
|---|---|---|---|---|
| `guest_id` | высокая | «мои брони» = 1 шард | B2B/OTA-аккаунт | **берём** |
| `property_id` | ок | partner-отчёты локальны; guest-list = scatter | сетевые отели | хуже под UX гостя |
| `booking_id` (hash) | идеальная | «мои брони» = scatter-gather | низкий | нет без вторичного индекса |

### Итоговая схема

| Сервис | Что шардируем | Ключ | Стратегия | Старт | Ребалансировка | Главный риск + лечение |
|---|---|---|---|---|---|---|
| Inventory | slots, holds, outbox | `property_id` | consistent hashing + vnodes | 16 | add node → часть ключей мигрирует | hotspot популярного отеля → соль / pin на шард (**не** смена ключа на room_type) |
| Booking | bookings, outbox | `guest_id` | consistent hashing; `booking_id` = ULID **+ shard_id** | 16 | то же | lookup по `booking_id` без directory — shard_id в id; «брони property X» → scatter-gather / read-model позже; OTA-hotspot → отдельный шард |

Cross-shard write-path Inventory: **нет** (все операции hold в рамках одного property).
Аналитика / OLAP — вне scope (ETL в колоночное хранилище).

---

## 4. Кэширование

| Что кэшируем | Уровень | Стратегия | TTL | Инвалидация | Зачем |
|---|---|---|---|---|---|
| Search-выдача (hot query) | Redis (app) | cache-aside | ~60 с | только TTL | снять повторные одинаковые гео-запросы с OpenSearch |
| Карточка property | Redis (app) | cache-aside | 10 мин | `DEL` по `catalog.updated` | редкие write, частые GET деталей |
| Booking status (polling) | Redis (app) | cache-aside | 2–3 с | `DEL` по `booking.*` | гасить polling storm после оплаты |
| Hold TTL index | Redis | hint + EXPIRE | = hold TTL (15 мин) | expire / delete при confirm/release | ускорить sweeper lookup; **SoT = Postgres** |
| thumbnail / медиа | CDN (edge) | CDN cache | дни + versioned URL | смена URL при замене файла | offload origin |
| JWKS / публичные ключи | Gateway | cache-aside | до ротации | по kid / TTL | не ходить в Identity на каждый запрос |

**Явно не кэшируем:**

- Payment intents / статусы платежей — нужна свежесть и аудит.
- `available count` как **permission** на hold — финальный Hold всегда в Inventory/Postgres (защита от double-sell / ложного sold-out из stale cache). Optimistic hint в MVP не делаем, чтобы не путать с Search CQRS.

Проблемы:

- **Stampede** на hot search — lock / probabilistic early expiration при SET.
- **Cold start** — lazy fill, без обязательного прогрева.
- **Eviction** — LRU в Redis; ключи поиска ограничены по cardinality (hash params + TTL).
- Redis keyspace notifications **не** единственный механизм истечения hold (ненадёжны при failover) — Inventory sweeper по Postgres обязателен ([ADR-0003](../../hw_02/solution/arc42/adr/0003-inventory-soft-hold.md)).

---

## 5. Очереди

_Где брокер сообщений, какой и почему._

## 6. CAP trade-offs

_Как решение соотносится с CAP-теоремой._
