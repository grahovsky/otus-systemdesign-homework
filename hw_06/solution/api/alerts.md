# API 6 — Threshold Alerts (REST)

CRUD правил, которые задаёт владелец приложения: порог на уже существующую funnel или
metric definition и `webhookUrl`. Query API периодически пересчитывает правило тем же
путём, что синхронный analytics-запрос, и при срабатывании делает HTTPS POST
([ADR-0006](../arc42/adr/0006-threshold-alerts-webhook.md),
[`../requirements.md` §1.1.6](../requirements.md#11-функциональные-требования-scope)).
Не BI и не anomaly detection: только явный порог.

Хранятся в PostgreSQL App & Config Service, таблица `alert_rules`
([`../data-storage.md` §1](../data-storage.md#1-модель-данных)).

## Общие заголовки (мутации)

```
Authorization: Bearer <jwt>
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json
```

`GET` — без `Idempotency-Key`, остальные заголовки те же.

## Create

`POST /v1/apps/{appId}/alerts`

Ровно одно из `funnelDefinitionId` / `metricDefinitionId`. Definition должна
принадлежать тому же `appId`; иначе 422.

```json
{
  "name": "checkout conversion drop",
  "funnelDefinitionId": "fun_checkout",
  "condition": {
    "on": "conversion",
    "dropPctGt": 20,
    "windowHours": 24,
    "baselineHours": 168
  },
  "webhookUrl": "https://hooks.example.com/telemetry"
}
```

`dropPctGt: 20` при `windowHours: 24` и `baselineHours: 168` означает: значение
за последние 24 ч ниже значения за предыдущие 7 суток более чем на 20%. Для
воронки `on=conversion` — конверсия последнего шага; для metric definition —
агрегат из `spec` ([`definitions.md`](definitions.md#2-metric-definitions)).

Response `201 Created`:

```json
{
  "alertId": "alrt_01J8Z...",
  "name": "checkout conversion drop",
  "funnelDefinitionId": "fun_checkout",
  "condition": {
    "on": "conversion",
    "dropPctGt": 20,
    "windowHours": 24,
    "baselineHours": 168
  },
  "webhookUrl": "https://hooks.example.com/telemetry",
  "updatedAt": "2026-09-16T10:00:00Z"
}
```

Секрет HMAC выдаётся один раз в заголовке `X-Webhook-Secret` ответа create/rotate
(не в теле и не при повторном GET) — тот же принцип показа, что plaintext API-ключа.
В Postgres секрет не хранится: `webhook_secret_ref` указывает в Vault; хеш неприменим,
потому что HMAC на отправке нужен plaintext ([`../security.md`](../security.md)).

## List / Get

`GET /v1/apps/{appId}/alerts` — список.
`GET /v1/apps/{appId}/alerts/{alertId}` — одно правило; `webhookSecret` не возвращается.

## Update / Rotate secret / Delete

`PUT /v1/apps/{appId}/alerts/{alertId}` — тело как в Create (`name`, definition, `condition`,
`webhookUrl`). Ответ `200 OK`. Новое условие применяется на следующей проверке по расписанию.

`POST /v1/apps/{appId}/alerts/{alertId}/secret/rotate` → `204` + новый `X-Webhook-Secret`.
Предыдущий секрет принимается ещё 5 мин (окно in-flight POST).

`DELETE /v1/apps/{appId}/alerts/{alertId}` → `204 No Content`. Последующие проверки
это правило пропускают; события в ClickHouse не затрагиваются.

## Доставка webhook (исходящий POST)

Query API, при срабатывании, `POST {webhookUrl}`:

```
Content-Type: application/json
X-Telemetry-Signature: sha256=<hex>
X-Request-Id: 8f14e45f-...
```

```json
{
  "alertId": "alrt_01J8Z...",
  "appId": "app_01J8Z...",
  "firedAt": "2026-09-16T10:15:00Z",
  "funnelDefinitionId": "fun_checkout",
  "condition": {
    "on": "conversion",
    "dropPctGt": 20,
    "windowHours": 24,
    "baselineHours": 168
  },
  "observed": {
    "window": 0.18,
    "baseline": 0.25,
    "dropPct": 28
  }
}
```

Подпись — HMAC-SHA256 тела на секрете правила (`X-Telemetry-Signature`).
Retry с exponential backoff, ограниченный бюджет; после исчерпания — запись
в аудит, правило не удаляется. Cooldown per-rule (по умолчанию = `windowHours`)
не даёт повторный POST на ту же просадку. Доставка at-least-once: получатель
идемпотентен по `(alertId, firedAt)`.

Расписание проверки — раз в 15 мин. Это не SLO ingest и не p95 Query API:
алерт — лучшее усилие с горизонтом минуты, согласованным с аналитикой часы/дни.

## Ошибки

| HTTP | Code | Когда |
|---|---|---|
| 401 | `UNAUTHENTICATED` | Нет/протух JWT владельца |
| 403 | `FORBIDDEN` | `appId` не принадлежит владельцу из токена |
| 404 | `ALERT_NOT_FOUND` / `DEFINITION_NOT_FOUND` | Правило или ссылаемая definition не существует |
| 422 | `INVALID_CONDITION` / `INVALID_WEBHOOK` | Оба id definition сразу; пустой порог; `webhookUrl` не HTTPS |

Повтор мутации с тем же `Idempotency-Key` → тот же ответ, без дублирования правила.

## Internal

`App & Config Service` читает/пишет `alert_rules` в PostgreSQL; валидация — сверка
`definition_id` с `funnel_definitions` / `metric_definitions` того же `appId`.
Query API забирает активные правила (HTTPS REST + mTLS), считает окно/baseline
в ClickHouse тем же путём, что [`analytics-query.md`](analytics-query.md), и
отправляет webhook. Своей БД у Query API по-прежнему нет.
