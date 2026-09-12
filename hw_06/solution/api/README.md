# API-контракты

> Часть [решения ДЗ 6](README.md), раздел 5 (Взаимодействие).

Отдельного API Gateway нет: у Ingest API и у App/Query API разная аутентификация
и разные клиенты (см. [`../architecture/`](../architecture/) и
[`../arc42/04-solution-strategy.md` §4.2](../arc42/04-solution-strategy.md#42-декомпозиция-сервисов)).

5 ключевых контрактов, по одному файлу на каждый:

| # | API | Протокол | Файл |
|---|---|---|---|
| 1 | Приём батча событий | REST | [`ingest-events.md`](ingest-events.md) |
| 2 | Конфиг SDK (sampling, feature flags, схема событий) | REST | [`sdk-config.md`](sdk-config.md) |
| 3 | Регистрация приложения и API-ключей | REST | [`app-registration.md`](app-registration.md) |
| 4 | Аналитика: funnel / retention / DAU-MAU / сегменты | REST | [`analytics-query.md`](analytics-query.md) |
| 5 | CRUD funnel/metric definitions | REST | [`definitions.md`](definitions.md) |

Заголовки Ingest API (клиент — мобильный SDK):

| Header | Обязателен | Описание |
|---|---|---|
| `X-Api-Key` | да | API-ключ зарегистрированного приложения |
| `Content-Encoding: gzip` | да для батча событий | сжатие тела запроса |
| `X-Request-Id` | рекомендуется | корреляция логов/трейсов |

Заголовки App & Config Service / Query API (клиент — владелец приложения):

| Header | Обязателен | Описание |
|---|---|---|
| `Authorization: Bearer <jwt>` | да | токен доступа владельца приложения |
| `Idempotency-Key` | для мутаций (регистрация ключей, definitions) | UUID |
| `X-Request-Id` | рекомендуется | корреляция логов/трейсов |
