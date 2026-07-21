# ADR-0004 — CQRS: Search как отдельный read-model

- **Status**: Accepted
- **Date**: 2026-07-12
- **Decision makers**: grahovsky

## Context

Поиск: high RPS, гео, фильтры, сортировки, денормализованные карточки.
Запись каталога/аллотмента: низкий RPS, строгие инварианты.

Одна нормализованная БД под оба паттерна доступа — типичный bottleneck.

## Decision

Выделить **Search Service** с индексом (OpenSearch):

- Пишется **асинхронно** из Kafka (`catalog.*`, `inventory.*`, `booking.confirmed|cancelled`)
- Читается sync через Gateway (GraphQL → gRPC)
- **Не** выполняет hold и не является source of truth доступности

Source of truth доступности на запись — Inventory; Search показывает eventually consistent срез.

## Consequences

### Позитивные

- Масштабирование поиска отдельно от write-path
- Удобные полнотекст/гео-запросы
- Catalog/Inventory остаются нормализованными

### Негативные / trade-offs

- Лаг проекции (секунды) — возможен stale «есть места»
- Финальная проверка всегда на Hold в Inventory

### Риски

- Рассинхрон индекса при баге consumer — нужен rebuild/replay из топиков

## Alternatives considered

### Поиск прямо в Catalog DB (SQL)

Проще на старте; плохо масштабируется под гео+фильтры+пики.

### Elasticsearch как primary для availability

Опасно для инвариантов overbooking — поисковый движок не заменяет транзакционный inventory.

## Links

- Related: ADR-0001, ADR-0003
