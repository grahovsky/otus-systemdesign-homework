# API 1 — Ingest Events (REST)

Приём батча событий от SDK. Синхронный ответ означает «батч принят в буфер (Kafka)», а не
«событие лежит в ClickHouse» ([ADR-0001](../arc42/adr/0001-batch-insert-clickhouse.md)).

## Endpoint

`POST /v1/events`

## Headers

```
X-Api-Key: ak_live_9f3c1e...
Content-Encoding: gzip
X-Request-Id: 8f14e45f-...
Content-Type: application/json
```

## Request

```json
{
  "batchId": "b_01J8Z...",
  "sentAt": "2026-09-09T10:15:03.201Z",
  "events": [
    {
      "eventId": "e_01J8Z8Q1KX3Z...",
      "eventName": "screen_view",
      "eventTime": "2026-09-09T10:14:58.500Z",
      "userId": "u_9f3c1e2a",
      "sessionId": "s_7c21ab",
      "appVersion": "3.4.1",
      "platform": "android",
      "properties": {
        "screen": "checkout"
      }
    }
  ]
}
```

`eventId` — генерируется SDK, ключ идемпотентности
([ADR-0002](../arc42/adr/0002-idempotency-not-exactly-once.md)). `properties` — только
зарегистрированные для приложения атрибуты; незаявленный ключ отклоняет батч целиком (fail
fast на границе, не частичная вставка).

`platform`/`appVersion` — от SDK; `country`/тип устройства Ingest API проставляет сам по
offline geo/device базе (IP/User-Agent), без внешнего вызова на hot path
([`requirements.md` §1.1](../requirements.md#11-функциональные-требования-scope)).

До 50 событий в батче или раз в 30 с — что раньше
([`requirements.md` §1.2](../requirements.md#12-нефункциональные-требования)).

## Response `202 Accepted`

```json
{
  "batchId": "b_01J8Z...",
  "accepted": 1,
  "duplicates": 0,
  "rejected": []
}
```

`202`, не `201`: батч подтверждён на уровне буфера, факт появления в ClickHouse клиенту не
гарантируется синхронно ([ADR-0001](../arc42/adr/0001-batch-insert-clickhouse.md)).

## Ошибки

| HTTP | Code | Когда |
|---|---|---|
| 401 | `INVALID_API_KEY` | Ключ не найден/отозван |
| 429 | `RATE_LIMITED` | Превышен per-app лимит (Redis-счётчик) |
| 422 | `SCHEMA_VIOLATION` | Незарегистрированный атрибут события или неверный тип поля |
| 413 | `BATCH_TOO_LARGE` | Батч больше лимита размера |

Повтор батча с теми же `eventId` внутри окна дедупа Redis → `duplicates` растёт, `accepted`
не задваивается ([ADR-0002](../arc42/adr/0002-idempotency-not-exactly-once.md)).

## Internal

1. Redis: проверка API-ключа/конфига (cache-aside, промах → запрос к App & Config Service)
2. Redis: окно дедупа по `eventId`, счётчик rate-limit
3. Geo/device lookup (offline)
4. Publish в Kafka `events.raw`
