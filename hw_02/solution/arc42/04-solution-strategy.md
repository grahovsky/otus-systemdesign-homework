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
TBD

## 4.4 Паттерны

| Паттерн | Где | Зачем |
|---|---|---|
| **Saga (orchestration)** | Booking | Многошаговый book/pay/cancel с компенсацией |

