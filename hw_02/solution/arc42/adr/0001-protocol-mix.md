# ADR-0001 — Микс протоколов: REST/GraphQL + gRPC + Kafka

- **Status**: Accepted
- **Date**: 2026-07-12
- **Decision makers**: grahovsky

## Context

Нужны: публичный API для web/mobile, низколатентные sync-команды между сервисами,
развязка для уведомлений и проекций. Один протокол на всё — антипаттерн
(см. [Таблицу протоколов](../../../Таблица%20протоколов.md)).

## Decision

| Зона | Протокол |
|---|---|
| Edge (команды, CRUD) | **REST** (OpenAPI) |
| Edge (поиск/карточки) | **GraphQL** |
| Sync inter-service | **gRPC** (+ Protobuf) |
| Async facts / fan-out | **Kafka** |
| Payment Provider | **REST + webhooks** (внешнее ограничение) |

## Consequences

### Позитивные

- Каждый тип взаимодействия — свой инструмент
- Строгие контракты внутри, удобный DX снаружи
- Пики поиска и нотификаций не валят write-path

### Негативные / trade-offs

- Два edge-протокола (REST + GraphQL) — больше gateway-логики
- Нужен Schema Registry / договорённости по событиям Kafka

### Риски

- Дублирование DTO REST↔gRPC на gateway — лечится codegen из единого IDL где возможно

## Alternatives considered

### Всё на REST

Проще, но слабый контракт внутри и нет естественного event-buffer.

### Всё на gRPC (включая клиентов)

Плохая поддержка в браузере; для публичного API избыточно.

### Только choreography через Kafka без sync gRPC

Hold/Authorize требуют ответа «сейчас» — чистый async ухудшает UX и усложняет таймауты.

## Links

- Таблица протоколов ДЗ 2
