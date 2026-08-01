# API 2 — Create Booking (REST)

Старт Saga: PENDING → soft-hold → PaymentIntent → HELD.
Списание денег и Confirm inventory — **не** в этом запросе (см. [`payment.md`](./payment.md)).

## Endpoint

`POST /v1/bookings`

## Headers

```
Authorization: Bearer <jwt>
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json
```

## Request

```json
{
  "propertyId": "prop_01HZX...",
  "roomTypeId": "rt_deluxe",
  "checkIn": "2026-08-10",
  "checkOut": "2026-08-12",
  "guests": { "adults": 2, "children": 0 },
  "priceSnapshot": {
    "amount": "18400.00",
    "currency": "RUB",
    "ratePlanId": "rp_flex"
  }
}
```

`guestProfileId` берётся из JWT (не из body — иначе IDOR).

`priceSnapshot` — цена с экрана; Booking сверяет с Catalog
(`PRICE_CHANGED` при расхождении сверх политики).

## Response `201 Created`

```json
{
  "bookingId": "bkg_01HZY...",
  "status": "HELD",
  "hold": {
    "holdId": "hld_01HZY...",
    "expiresAt": "2026-07-12T22:05:00Z"
  },
  "payment": {
    "paymentIntentId": "pay_01HZY...",
    "clientSecret": "cs_test_...",
    "status": "REQUIRES_CONFIRMATION"
  },
  "amount": { "amount": "18400.00", "currency": "RUB" }
}
```

Если hold/intent ещё не завершились атомарно с точки зрения клиента — не отдаём
частичный успех: либо `201 HELD`, либо ошибка с компенсацией (release, если hold уже взят).

## Ошибки

| HTTP | Code | Когда |
|---|---|---|
| 409 | `SOLD_OUT` | Inventory не смог hold |
| 409 | `PRICE_CHANGED` | Тариф изменился |
| 422 | `INVALID_DATES` | Некорректные даты |
| 401 | `UNAUTHENTICATED` | Нет/протух JWT |

Повтор с тем же `Idempotency-Key` → тот же `201` body (без второго hold).

## Internal (sync шаги саги)

1. insert booking PENDING (outbox later)  
2. `inventory.v1.Hold`  
3. `payment.v1.CreateIntent`  
4. status HELD + publish `booking.held`
