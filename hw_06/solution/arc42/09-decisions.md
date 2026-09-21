# 9. Architecture decisions

> Часть [решения ДЗ 6](../README.md). Полные ADR — в [`adr/`](adr/).

## Принятые ADR

| ADR | Название | Статус | Решение (кратко) |
|---|---|---|---|
| [ADR-0001](adr/0001-batch-insert-clickhouse.md) | Батч-вставка vs построчная запись в ClickHouse | Accepted | Построчный INSERT — антипаттерн ClickHouse; буфер Kafka + Storage Writer с батчингом (см. [`04-solution-strategy.md` §4.1](04-solution-strategy.md#41-архитектурный-стиль)) |
| [ADR-0002](adr/0002-idempotency-not-exactly-once.md) | Идемпотентность вместо exactly-once | Accepted | SDK может повторить батч после таймаута; дедуп по `event_id` в окне Redis и при вставке в ClickHouse, а не попытка гарантировать ровно одну доставку на транспорте (см. [`../requirements.md` §1.3](../requirements.md#13-риски-и-ограничения)) |
| [ADR-0003](adr/0003-query-time-vs-pre-aggregation.md) | Query-time агрегация vs pre-aggregation | Accepted | На MVP — query-time расчёт по сырым событиям ClickHouse; отдельные materialized views под DAU/MAU (retention 2 года), без pre-aggregation под каждый из 4 query-эндпоинтов |
| [ADR-0004](adr/0004-shard-by-app-id.md) | Шардирование ClickHouse по `app_id` | Accepted | Шард-ключ — `app_id`, не `hash(user_id)`: funnel/retention/сегменты всегда фильтруют по одному `appId`; hotspot-приложение остаётся точечной эскалацией, не меняет ключ для всех |
| [ADR-0005](adr/0005-ingest-config-degraded-mode.md) | Деградация Ingest при недоступности App & Config | Accepted | При промахе кэша и недоступном App & Config Ingest обслуживает запрос из просроченного кэша до 30 мин (fail-open, ограниченный по времени), не отклоняет батч сразу (fail-closed) — иначе Tier 1-сбой App & Config эскалирует в Tier 0-потерю событий (см. [`../reliability.md` §3](../reliability.md#3-паттерны-отказоустойчивости)) |
| [ADR-0006](adr/0006-threshold-alerts-webhook.md) | Пороговый алерт vs BI-платформа / отдельный сервис | Accepted | Правило на funnel/metric definition, периодический пересчёт тем же путём Query API, доставка HMAC-webhook. Состояние проверки — `alert_state` и одна строка `alert_scheduler_lease` в Postgres App & Config: второй инстанс Query API тик не выполняет, повторный webhook отсекает условный UPDATE cooldown. Полноценные дашборды и ML — backlog; отдельный Alert Service не даёт изоляции, которой нет у синхронного запроса тех же definitions |

## Кандидаты (закрыты в security.md, без отдельного ADR)

Развилки ниже не тянут на ADR уровня 0001–0006: одна закрыта отсутствием контейнера в C2,
вторая — уточнение транспорта на уже выбранных HTTP-рёбрах.

| Тема | Решение | Почему не ADR |
|---|---|---|
| Identity в C2 vs внешний IdP | JWT владельца выпускает внешний IdP; App & Config и Query API проверяют подпись по кэшируемому JWKS. Identity-сервис в C2 не добавляем | Логин/пароль владельца не часть цепочки ingest → аналитика; JWT уже в API-контрактах без своего issuer. Полный ADR дублировал бы [`../security.md` §1](../security.md#1-аутентификация--авторизация) |
| mTLS на внутренних HTTP при отсутствии gRPC | mTLS + короткоживущий service identity на Ingest/Query → App & Config; Kafka/CH/PG/Redis — TLS + credentials из секрет-хранилища | Протокольное уточнение [`04-solution-strategy.md` §4.3](04-solution-strategy.md#43-протоколы--микс): синхронных многошаговых команд нет, отдельный RPC-слой не нужен. Сеть внутри кластера не доверенная — тот же аргумент, что в Bookly, без смены стиля взаимодействия |
