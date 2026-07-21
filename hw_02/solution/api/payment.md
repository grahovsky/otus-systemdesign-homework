# API 3 — Payment (REST) + Webhook

Два входа: confirm от гостя и webhook провайдера.
**Payment не выставляет `booking.status`** — это делает Booking по `payment.*` событиям.

## 3.1 Confirm payment (guest-facing)

`POST /v1/payments/{paymentIntentId}/confirm`

```
Authorization: Bearer <jwt>
Idempotency-Key: confirm:pay_01HZY...
```

```json
{
  "bookingId": "bkg_01HZY...",
  "returnUrl": "https://app.bookly.example/bookings/bkg_01HZY..."
}
```

### Response `200` (пример без 3DS)

```json
{
  "paymentIntentId": "pay_01HZY...",
  "status": "PROCESSING",
  "bookingId": "bkg_01HZY..."
}
```

Либо `status: REQUIRES_ACTION` + `redirectUrl` для 3DS.

Клиент **не** ждёт `CONFIRMED` в этом ответе: после returnUrl делает
`GET /v1/bookings/{bookingId}` (или SSE/poll), пока статус не `CONFIRMED` / `CANCELLED` / `EXPIRED`.

В быстрых sandbox-сценариях провайдер может сразу прислать captured — тогда
следующий GET уже увидит `CONFIRMED`, но контракт confirm остаётся про **платёж**.

## 3.2 Webhook от Payment Provider

`POST /v1/webhooks/payment-provider`  
(без JWT гостя; проверка `X-Provider-Signature`)

```
X-Provider-Signature: <hmac>
Content-Type: application/json
```

```json
{
  "eventId": "evt_123",
  "type": "payment.captured",
  "paymentIntentId": "pay_01HZY...",
  "bookingId": "bkg_01HZY...",
  "amount": { "amount": "18400.00", "currency": "RUB" },
  "occurredAt": "2026-07-12T21:52:10Z"
}
```

Gateway → Payment (gRPC). Дедуп по `eventId`. Payment → Kafka `payment.captured`;
Booking → `ConfirmInventory` → `CONFIRMED`.

`payment.failed` → Booking `Release` → `CANCELLED` (или оставляет HELD до TTL — политика;
в Bookly: сразу compensate).

## Ошибки

| HTTP | Code | Когда |
|---|---|---|
| 409 | `IDEMPOTENCY_CONFLICT` | Тот же ключ, другое тело |
| 404 | `NOT_FOUND` | Неизвестный intent |
| 409 | `HOLD_EXPIRED` | TTL hold истёк до confirm (Booking/Inventory уже EXPIRED) |
| 401 | `INVALID_SIGNATURE` | Webhook HMAC невалиден |

## Internal

- `payment.v1.Confirm` / `Refund`
- Таблица `idempotency_keys` + `webhook_events` в `db-payment`
- См. [ADR-0005](../arc42/adr/0005-payment-idempotency.md), [ADR-0002](../arc42/adr/0002-saga-orchestration.md)
