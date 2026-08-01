# ADR-0002 — Orchestrated Saga в Booking Service

- **Status**: Accepted
- **Date**: 2026-07-12
- **Decision makers**: grahovsky

## Context

Бронирование = несколько участников с разными транзакциями БД:
Inventory (hold/confirm), Payment (intent/capture), Booking (статус).
2PC между сервисами не рассматриваем (хрупко, блокировки).

Нужны компенсации: failed pay → release hold; cancel → refund + release.
Нельзя одновременно иметь «Booking вызывает Release» и «Inventory сам release по `booking.cancelled`»
— двойная семантика и гонки.

## Decision

**Orchestrated Saga** с оркестратором в **Booking Service**:

1. `CreateBooking` → PENDING  
2. gRPC `HoldInventory` (TTL) →  
3. gRPC `CreatePaymentIntent` → статус **HELD** (ответ клиенту: `hold` + `clientSecret`)  
4. Клиент confirm у Payment; провайдер шлёт webhook → `payment.captured`  
5. Booking (по событию) → gRPC `ConfirmInventory` → **CONFIRMED**  
6. fail / cancel → gRPC `Release` + при необходимости `Refund` → CANCELLED  
7. TTL: **Inventory sweeper** снимает hold и публикует `inventory.released` → Booking → **EXPIRED**

Состояние саги — в `db-booking`. События наружу — outbox.

Правило владения:

| Действие | Кто |
|---|---|
| hold / confirm / release (по бизнес-причине) | **Booking → Inventory (gRPC)** |
| снятие просроченного hold | **Inventory sweeper** → событие |
| смена статуса брони | **только Booking** |

## Consequences

### Позитивные

- Единое место, где смотреть статус брони
- Нет двойного release-path
- Компенсации явные

### Негативные / trade-offs

- Booking — критичный оркестратор (идемпотентность шагов обязательна)
- CONFIRMED не синхронен с `POST .../confirm` — клиент polling/redirect после webhook

### Риски

- Оркестратор стал «god» — ограничиваем только сагой брони
- Потеря `payment.captured` → нужен reconcile job Booking↔Payment

## Alternatives considered

### Choreography-only

Меньше центра, но сложнее понять текущий шаг и отладить «потерянные» компенсации.

### Inventory слушает `booking.cancelled` и сам release

Дублирует оркестратор; при повторных событиях и частичных фейлах хуже рассуждать о инвариантах.

## Links

- §4 Solution Strategy
