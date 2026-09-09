# ADR-0003 — Query-time агрегация vs pre-aggregation

- **Status**: Accepted
- **Date**: 2026-09-06
- **Decision makers**: архитектор

## Context

Query API отдаёт четыре эндпоинта: conversion воронки, кривая retention, DAU/MAU,
разбивка по сегментам. SLO — p95 < 2 с
([`../../requirements.md` §1.2](../../requirements.md#12-нефункциональные-требования)).
Воронка и retention — аналитика с горизонтом часы/дни, не интерактивный UI
с сотнями миллисекунд. Pre-aggregation под каждый эндпоинт снижает latency
запроса ценой поддержки отдельных агрегатов и ограничения гибкости definitions.

Сырые события хранятся 90 дней; тренды DAU/MAU нужны 2 года — сырьё за этот
срок не держат.

## Decision

На MVP — query-time расчёт по сырым событиям ClickHouse для воронки, retention
и сегментов. Отдельные материализованные представления — только под DAU/MAU
с retention 2 года. Pre-aggregation под каждый из четырёх эндпоинтов не вводится.

Определения воронок/метрик читаются из App & Config Service в момент запроса,
а не зашиваются в заранее посчитанный агрегат.

## Consequences

### Позитивные

- Смена funnel/metric definition не требует пересчёта витрин
- Один SoT (сырые события) для трёх из четырёх эндпоинтов
- DAU/MAU за горизонт дольше 90 дней закрываются без хранения сырых событий
  за 2 года

### Негативные / trade-offs

- p95 query зависит от объёма сырых событий и кардинальности `user_id`
- Нет субагрегатов под произвольную воронку — укладываемся в 2 с, а не в
  интерактивные сотни миллисекунд (дашборды sub-second — backlog §1.4)

### Риски

- Рост кардинальности атрибутов ломает время funnel/retention.
  Митигация — фиксированный регистрируемый набор атрибутов
  ([`../../requirements.md` §1.3](../../requirements.md#13-риски-и-ограничения)).

## Alternatives considered

### Pre-aggregation под каждый из четырёх эндпоинтов

Ниже latency, но definitions воронки становятся схемой витрины: смена шагов
требует backfill. На объёме MVP и SLO p95 < 2 с избыточно.

### Stream processing «текущего DAU» (Flink / ksqlDB)

Нужен отдельный stream-слой. Четыре query-эндпоинта этого не требуют;
вынесено в backlog ([`../../requirements.md` §1.4](../../requirements.md#14-backlog-что-не-входит-в-scope)).

## Links

- [`../04-solution-strategy.md` §4.2](../04-solution-strategy.md#42-декомпозиция-сервисов)
- Related: [ADR-0001](0001-batch-insert-clickhouse.md)
