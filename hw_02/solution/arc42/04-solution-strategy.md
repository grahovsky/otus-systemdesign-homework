# arc42 §4 — Solution Strategy

> Детали решений — в ADR (§9). Схемы — LikeC4 C1/C2.

## 4.0 Общий подход

Bookly — **микросервисная** система с чётким разделением write-path бронирования
и read-path поиска. Между сервисами — **gRPC** для команд с ответом,
**Kafka** для фактов и fan-out, **REST** (и GraphQL для поиска) на edge.
Критический путь `hold → pay → confirm` оркестрируется
**Booking Service** (Saga).

## 4.1 Декомпозиция (8 сервисов)

| # | Сервис | Ответственность | Не делает |
|---|---|---|---|
| 1 | **API Gateway** | TLS, JWT, rate limit, REST/GraphQL → gRPC | Бизнес-логика брони |
| 2 | **Identity** | Аккаунты, роли guest/partner/admin, JWT | Платежи, инвентарь |
| 3 | **Catalog** | Объекты, room types, контент, rate plans | Календарь слотов |
| 4 | **Search** | Геопоиск/фильтры (CQRS read-model) | Soft-hold, оплата |
| 5 | **Inventory** | Аллотмент, soft-hold TTL, confirm/release | Оркестрация оплаты |
| 6 | **Booking** | Агрегат брони + **оркестратор Saga** | Доставка email |
| 7 | **Payment** | PaymentIntent, confirm/capture/refund, idempotency, webhooks | Статус брони, выбор номера |
| 8 | **Notification** | Шаблоны + email/SMS по событиям | Решение об отмене |

Инфраструктура (не считаем отдельными «бизнес-сервисами»): Kafka, Redis, PostgreSQL per service, OpenSearch.

Почему не god-service: Inventory и Payment изолированы — разные consistency-требования
и разные внешние зависимости. Почему не дробим дальше: отдельный «Pricing» /
«Cancellation Policy» пока внутри Catalog/Booking — иначе избыточное дробление.

## 4.2 Протоколы (микс)

| Ребро | Протокол | Почему |
|---|---|---|
| Client → Gateway | **REST** | Публичный CRUD/команды, кэш GET, простота mobile/web |
| Client → Gateway (поиск) | **GraphQL** | Гибкая проекция карточек под web/mobile без overfetch |
| Gateway → сервисы | **gRPC** | Строгий контракт, low latency, codegen |
| Booking → Inventory / Payment | **gRPC** | Sync-шаги Saga: нужен ответ hold/authorize здесь и сейчас |
| Доменные факты | **Kafka** | Развязка, buffer пиков, fan-out Search/Notification, replay |
| Payment Provider | **REST + webhooks** | Внешнее ограничение провайдера |
| Availability push в UI (опц.) | **SSE** | Односторонние обновления «слот занят» на выдаче |

Опора: [Таблица протоколов](../../Таблица%20протоколов.md) — нет «лучшего» протокола,
есть подходящий под сценарий.

## 4.3 Асинхронность — где и зачем

| Сценарий | Async? | Почему |
|---|---|---|
| Поиск | Sync (GraphQL/gRPC) | Гость ждёт выдачу в UI |
| Soft-hold + CreateIntent | Sync gRPC | Без hold и intent нельзя вести на оплату |
| Confirm/capture у провайдера | Sync edge + **async webhook** | UX инициирует confirm; финальный captured часто приходит webhook'ом |
| Проекция Search | **Async Kafka** | Search eventual; не блокирует запись каталога/инвентаря |
| Email/SMS | **Async Kafka** | Не на критическом пути; retry независимо |
| Release по TTL | **Async** (Inventory sweeper → `inventory.released`) | Истечение hold не инициирует гость; Booking закрывает сагу в EXPIRED |
| Компенсация после failed payment / cancel | Sync gRPC Release (+ Refund) от Booking | Оркестратор владеет компенсацией; Inventory не слушает `booking.*` |

## 4.4 Паттерны

| Паттерн | Где | Зачем |
|---|---|---|
| **Saga (orchestration)** | Booking | Многошаговый book/pay/cancel с компенсацией |
| **CQRS** | Search vs Catalog/Inventory | Разные нагрузки и модели чтения/записи |
| **Soft lock / Hold + TTL** | Inventory | Снижение overbooking без долгой блокировки |
| **Idempotency keys** | Booking create + Payment | Ретраи клиента/сети без двойного hold/списания |
| **Transactional Outbox** | Booking (и др. writers) | Надёжная публикация в Kafka после commit |
| **API Gateway** | Edge | Единый auth/rate-limit, скрытие внутренней топологии |

Анти-паттерны, которых избегаем: distributed monolith через болтливый sync на каждый
read; choreography-only Saga без явного состояния; **двойной release**
(и Booking gRPC, и Inventory по `booking.cancelled`) — release/confirm только от оркестратора,
TTL — локальный sweeper Inventory.
