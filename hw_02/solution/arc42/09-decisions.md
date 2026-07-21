# arc42 §9 — Architecture Decisions

ADR — один файл на решение. Шаблон: [`adr/_template.md`](./adr/_template.md).

## Принятые решения

| ADR | Статус | Решение |
|---|---|---|
| [ADR-0001](./adr/0001-protocol-mix.md) | Accepted | Микс REST + GraphQL (edge), gRPC (internal), Kafka (events) |
| [ADR-0002](./adr/0002-saga-orchestration.md) | Accepted | Orchestrated Saga в Booking Service |
| [ADR-0003](./adr/0003-inventory-soft-hold.md) | Accepted | Soft-hold с TTL как защита от overbooking |
| [ADR-0004](./adr/0004-cqrs-search.md) | Accepted | CQRS: Search как отдельный read-model |
| [ADR-0005](./adr/0005-payment-idempotency.md) | Accepted | Idempotency-Key на все платёжные мутации |

## Статусы

- **Proposed** — обсуждается
- **Accepted** — действует
- **Deprecated** / **Superseded by ADR-XXXX** — заменено
