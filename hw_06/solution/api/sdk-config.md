# API 2 — Fetch SDK Config (REST)

SDK тянет конфиг при старте сессии: sampling rate, feature flags, зарегистрированная схема
атрибутов события (для локальной валидации до отправки).

## Endpoint

`GET /v1/sdk/config`

## Headers

```
X-Api-Key: ak_live_9f3c1e...
X-Request-Id: 8f14e45f-...
```

## Response `200 OK`

```json
{
  "appId": "app_01J8Z...",
  "samplingRate": 1.0,
  "featureFlags": {
    "extendedScreenEvents": true
  },
  "eventSchemaVersion": 7,
  "allowedProperties": {
    "screen_view": ["screen"],
    "purchase": ["sku", "amount", "currency"]
  }
}
```

`samplingRate` — доля событий, которые SDK должен реально отправлять (1.0 — все). Снижается
владельцем приложения без релиза, если пиковая нагрузка события требует снижения объёма
([`requirements.md` §1.1](../requirements.md#11-функциональные-требования-scope)).

## Ошибки

| HTTP | Code | Когда |
|---|---|---|
| 401 | `INVALID_API_KEY` | Ключ не найден/отозван |
| 404 | `APP_NOT_FOUND` | Приложение не зарегистрировано |

Кэшируется на стороне SDK на время сессии; сервер не обязан отвечать быстрее latency-бюджета
ingest — это не hot path приёма события.

## Internal

`App & Config Service` читает данные приложения из PostgreSQL напрямую (не hot path записи,
редкие запросы за сессию).
