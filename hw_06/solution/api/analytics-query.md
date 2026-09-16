# API 4 — Query Analytics (REST)

Четыре read-эндпоинта Query API. Общая модель: владелец приложения читает данные только
своих приложений (`appId` из пути, доступ проверяется по владению — не по значению в body).
Query-time расчёт по сырым событиям ClickHouse, кроме DAU/MAU — из материализованного
представления ([ADR-0003](../arc42/adr/0003-query-time-vs-pre-aggregation.md)).

## Общие заголовки

```
Authorization: Bearer <jwt>
X-Request-Id: 8f14e45f-...
```

## 1. Funnel conversion

`GET /v1/apps/{appId}/analytics/funnel?definitionId={id}&from=2026-09-01&to=2026-09-07`

```json
{
  "definitionId": "fun_checkout",
  "period": { "from": "2026-09-01", "to": "2026-09-07" },
  "steps": [
    { "name": "screen_view:home", "users": 120000, "conversionFromPrev": 1.0 },
    { "name": "screen_view:checkout", "users": 42000, "conversionFromPrev": 0.35 },
    { "name": "purchase", "users": 9800, "conversionFromPrev": 0.233 }
  ]
}
```

Шаги воронки — из definition, зарегистрированного через `App & Config Service`
([`sdk-config.md`](sdk-config.md) — тот же источник определений).

## 2. Retention curve

`GET /v1/apps/{appId}/analytics/retention?cohort=2026-09-01&horizonDays=30`

```json
{
  "cohort": "2026-09-01",
  "cohortSize": 15000,
  "points": [
    { "day": 1, "retainedUsers": 6200, "retentionRate": 0.413 },
    { "day": 7, "retainedUsers": 2400, "retentionRate": 0.16 },
    { "day": 30, "retainedUsers": 900, "retentionRate": 0.06 }
  ]
}
```

## 3. DAU / MAU

`GET /v1/apps/{appId}/analytics/dau-mau?from=2026-08-01&to=2026-09-01`

```json
{
  "period": { "from": "2026-08-01", "to": "2026-09-01" },
  "points": [
    { "date": "2026-08-01", "dau": 41000, "mau": 250000 }
  ]
}
```

Источник — материализованное представление с retention 2 года, не сырые события за тот же
срок ([ADR-0003](../arc42/adr/0003-query-time-vs-pre-aggregation.md)).

## 4. Сегменты

`GET /v1/apps/{appId}/analytics/segments?metric=dau&groupBy=platform&date=2026-09-01`

```json
{
  "metric": "dau",
  "groupBy": "platform",
  "date": "2026-09-01",
  "segments": [
    { "value": "android", "count": 28000 },
    { "value": "ios", "count": 13000 }
  ]
}
```

`groupBy` ограничен зарегистрированными атрибутами (`platform`, `appVersion`, `country`) —
произвольная кардинальность здесь не поддерживается
([`requirements.md` §1.3](../requirements.md#13-риски-и-ограничения)).

## Ошибки (общие для всех 4 эндпоинтов)

| HTTP | Code | Когда |
|---|---|---|
| 401 | `UNAUTHENTICATED` | Нет/протух JWT |
| 403 | `FORBIDDEN` | `appId` не принадлежит владельцу из токена |
| 404 | `DEFINITION_NOT_FOUND` | `definitionId` не существует (только для funnel) |
| 422 | `INVALID_RANGE` | Период вне допустимого горизонта (сырые события — 90 дней, кроме DAU/MAU) |
| 504 | `QUERY_TIMEOUT` | Запрос превысил latency-бюджет p95 < 2 с |

## Internal

Query API читает funnel/metric definitions и alert-правила из `App & Config Service`
(HTTPS REST, не hot path) и данные — из ClickHouse (Native protocol). Периодическая
проверка алертов — тот же read-path по расписанию ([`alerts.md`](alerts.md)).
