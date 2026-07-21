# API 4 — Cancel Booking (REST)

Отмена с компенсацией: release inventory + refund (если было списание).

## Endpoint

`POST /v1/bookings/{bookingId}/cancel`

## Headers

```
Authorization: Bearer <jwt>
Idempotency-Key: cancel:bkg_01HZY...
Content-Type: application/json
```

## Request

```json
{
  "reason": "GUEST_REQUEST",
  "comment": "Планы изменились"
}
```

`reason` (guest/partner/admin API): `GUEST_REQUEST` | `PARTNER_REQUEST` | `ADMIN`  
Системные причины (`PAYMENT_FAILED`, `HOLD_EXPIRED`) выставляет сам Booking, не клиент.

## Response `200`

```json
{
  "bookingId": "bkg_01HZY...",
  "status": "CANCELLED",
  "refund": {
    "refundId": "rfd_01HZY...",
    "status": "SUCCEEDED",
    "amount": { "amount": "18400.00", "currency": "RUB" }
  },
  "inventory": { "released": true }
}
```

Если бронь была только `HELD` (ещё не captured) — `refund: null`, только release.

## Ошибки

| HTTP | Code | Когда |
|---|---|---|
| 409 | `ALREADY_CANCELLED` | Повторная отмена (идемпотентный успех предпочтительнее) |
| 422 | `CANCEL_NOT_ALLOWED` | Политика отмены (non-refundable после cutoff) |
| 404 | `NOT_FOUND` | Нет брони / чужая бронь |

Политика non-refundable живёт в Booking (по `ratePlanId` из snapshot);
Payment вызывается только если refund разрешён и был capture.

## Internal (Saga compensate)

1. Проверка политики  
2. gRPC `inventory.Release` (если ещё held/sold → снова available)  
3. gRPC `payment.Refund` при необходимости  
4. status `CANCELLED` + events `booking.cancelled` → Notification, Search
