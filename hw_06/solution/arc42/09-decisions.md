# 9. Architecture decisions

> Часть [решения ДЗ 6](../README.md). Полные ADR — в [`adr/`](adr/).

## Принятые ADR

| ADR | Название | Статус | Решение (кратко) |
|---|---|---|---|
| [ADR-0001](adr/0001-batch-insert-clickhouse.md) | Батч-вставка vs построчная запись в ClickHouse | Accepted | Построчный INSERT — антипаттерн ClickHouse; буфер Kafka + Storage Writer с батчингом (см. [`04-solution-strategy.md` §4.1](04-solution-strategy.md#41-архитектурный-стиль)) |
| [ADR-0002](adr/0002-idempotency-not-exactly-once.md) | Идемпотентность вместо exactly-once | Accepted | SDK может повторить батч после таймаута; дедуп по `event_id` в окне Redis и при вставке в ClickHouse, а не попытка гарантировать ровно одну доставку на транспорте (см. [`../requirements.md` §1.3](../requirements.md#13-риски-и-ограничения)) |
| [ADR-0003](adr/0003-query-time-vs-pre-aggregation.md) | Query-time агрегация vs pre-aggregation | Accepted | На MVP — query-time расчёт по сырым событиям ClickHouse; отдельные materialized views под DAU/MAU (retention 2 года), без pre-aggregation под каждый из 4 query-эндпоинтов |
| [ADR-0004](adr/0004-shard-by-app-id.md) | Шардирование ClickHouse по `app_id` | Accepted | Шард-ключ — `app_id`, не `hash(user_id)`: funnel/retention/сегменты всегда фильтруют по одному `appId`; hotspot-приложение остаётся точечной эскалацией, не меняет ключ для всех |
