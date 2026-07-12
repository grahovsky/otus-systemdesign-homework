# ДЗ 2. Проектирование взаимодействия сервисов — решение

> Условие: [../Задание.md](../Задание.md) · Таблица протоколов: [../Таблица протоколов.md](../Таблица%20протоколов.md)
> Схемы складывайте в [diagrams/](diagrams/).

## Выбранная система

**Сервис бронирования (Bookly)** — аналог Booking.com: поиск, soft-hold инвентаря, оплата, отмены.

Формат документации — LikeC4 (C1/C2) + arc42 §1/§4/§5/§9 + ADR.
ER/PlantUML - для моделей данных (hw_03)

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

_REST / gRPC / GraphQL / events — где и почему._

## 3. Схема взаимодействия

_PNG/PlantUML с указанием протоколов (в diagrams/)._

## 4. API-контракты

_3–4 ключевых API (Swagger/OpenAPI или описание)._

## 5. Асинхронность

_Где применяется и почему._

## 6. Паттерны

_Saga, CQRS и т.д. — обоснование._
