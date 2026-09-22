# API 3 — Register App & Rotate Keys (REST)

Владелец приложения регистрирует приложение и получает API-ключ для встраивания в SDK.

## Endpoint

`POST /v1/apps`

## Headers

```
Authorization: Bearer <jwt>
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Content-Type: application/json
```

## Request

```json
{
  "name": "MyShop Android",
  "platform": "android",
  "eventSchema": {
    "screen_view": ["screen"],
    "purchase": ["sku", "amount", "currency"]
  }
}
```

`eventSchema` — исчерпывающий список атрибутов, которые Ingest API примет для этого
приложения; событие с незаявленным свойством отклоняется
([`requirements.md` §1.3](../requirements.md#13-риски-и-ограничения)).

## Response `201 Created`

```json
{
  "appId": "app_01J8Z...",
  "apiKey": "ak_live_9f3c1e...",
  "createdAt": "2026-09-09T10:00:00Z"
}
```

`apiKey` возвращается только один раз при создании; повторный просмотр невозможен — только
ротация (`POST /v1/apps/{appId}/keys/rotate`, тот же паттерн ответа).

## Ошибки

| HTTP | Code | Когда |
|---|---|---|
| 401 | `UNAUTHENTICATED` | Нет/протух JWT владельца |
| 409 | `NAME_TAKEN` | Приложение с таким именем уже существует у владельца |
| 422 | `INVALID_SCHEMA` | Схема события пуста или некорректна |

Повтор с тем же `Idempotency-Key` → тот же `201` body (без создания дубликата приложения).

## Internal

`App & Config Service` пишет в PostgreSQL (`apps`, `api_keys`) в одной транзакции.
