# API 5 — Funnel & Metric Definitions (REST)

CRUD для определений, которые задаёт владелец приложения и по которым считает Query API:
шаги воронки и именованные метрики ([`requirements.md` §1.1.3](../requirements.md#11-функциональные-требования-scope)).
Хранятся в PostgreSQL App & Config Service, таблицы `funnel_definitions` /
`metric_definitions` ([`../data-storage.md` §1](../data-storage.md#1-модель-данных)).
Query-time чтение, без пересчёта витрин при смене шагов
([ADR-0003](../arc42/adr/0003-query-time-vs-pre-aggregation.md)).

## Общие заголовки (мутации)

```
Authorization: Bearer <jwt>
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json
```

`GET` — без `Idempotency-Key`, остальные заголовки те же.

## 1. Funnel definitions

### Create

`POST /v1/apps/{appId}/definitions/funnel`

```json
{
  "name": "checkout",
  "steps": ["screen_view:home", "screen_view:checkout", "purchase"]
}
```

Каждый шаг — `eventName` (опционально `eventName:property=value`), должен ссылаться на
событие/атрибут, зарегистрированный в `apps.eventSchema`
([`app-registration.md`](app-registration.md)); незарегистрированный шаг отклоняется —
тот же принцип fail fast на границе, что и на ingest.

Response `201 Created`:

```json
{
  "definitionId": "fun_checkout",
  "name": "checkout",
  "steps": ["screen_view:home", "screen_view:checkout", "purchase"],
  "updatedAt": "2026-09-09T10:00:00Z"
}
```

### List / Get

`GET /v1/apps/{appId}/definitions/funnel` — список.
`GET /v1/apps/{appId}/definitions/funnel/{definitionId}` — одна definition; `definitionId`
из этого ответа — тот же параметр, что принимает
[`analytics-query.md` §1](analytics-query.md#1-funnel-conversion).

### Update

`PUT /v1/apps/{appId}/definitions/funnel/{definitionId}` — тело как в Create (`name`,
`steps`). Ответ `200 OK`, `updatedAt` обновлён. Новые шаги видны на следующем запросе
funnel — без backfill, т.к. расчёт query-time ([ADR-0003](../arc42/adr/0003-query-time-vs-pre-aggregation.md)).

### Delete

`DELETE /v1/apps/{appId}/definitions/funnel/{definitionId}` → `204 No Content`. Последующий
запрос funnel с этим `definitionId` → `404 DEFINITION_NOT_FOUND`
([`analytics-query.md`](analytics-query.md#ошибки-общие-для-всех-4-эндпоинтов)). Сами
события в ClickHouse не затрагиваются — definition не хранит расчётных данных.

## 2. Metric definitions

Тот же CRUD-паттерн, что у funnel: `POST/GET/PUT/DELETE /v1/apps/{appId}/definitions/metric[/{definitionId}]`,
тело — `name` + `spec` (JSON: событие-метрика и опционально числовой атрибут для агрегации,
например `{"event": "purchase", "aggregate": "sum", "property": "amount"}`).
Потребитель `metric_definitions` в Query API — пороговый алерт
([`alerts.md`](alerts.md)): правило ссылается на `metricDefinitionId` (или на воронку),
а не отдельный пятый analytics-эндпоинт. Четыре query-эндпоинта из §1.1 остаются
фиксированными; произвольная метрика считается только при проверке правила
([ADR-0006](../arc42/adr/0006-threshold-alerts-webhook.md)).

## Ошибки (общие)

| HTTP | Code | Когда |
|---|---|---|
| 401 | `UNAUTHENTICATED` | Нет/протух JWT владельца |
| 403 | `FORBIDDEN` | `appId` не принадлежит владельцу из токена |
| 404 | `DEFINITION_NOT_FOUND` | `definitionId` не существует |
| 422 | `INVALID_STEPS` / `INVALID_SPEC` | Шаг/спека ссылается на незарегистрированное событие или атрибут |

Повтор мутации с тем же `Idempotency-Key` → тот же ответ, без дублирования definition.

## Internal

`App & Config Service` читает/пишет `funnel_definitions` / `metric_definitions` в
PostgreSQL; валидация шага/спеки — сверка с `apps.event_schema` того же `appId` в одной
транзакции чтения.
