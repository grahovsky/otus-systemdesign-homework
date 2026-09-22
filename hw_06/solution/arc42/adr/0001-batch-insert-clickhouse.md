# ADR-0001 — Батч-вставка vs построчная запись в ClickHouse

- **Status**: Accepted
- **Date**: 2026-09-06
- **Decision makers**: архитектор

## Context

Ingest принимает батчи событий от SDK с SLO p99 < 300 мс
([`../../requirements.md` §1.2](../../requirements.md#12-нефункциональные-требования)).
ClickHouse — SoT сырых событий. Построчный или частый мелкий INSERT в MergeTree —
известный антипаттерн: вставки плохо сжимаются и порождают избыточное число
partition-частей. Синхронная запись Ingest API → ClickHouse привязала бы p99 ingest
к скорости OLAP-вставки под пиковой нагрузкой (peak factor ×3).

## Decision

Ingest API пишет только в Kafka (`events.raw`). Единственный writer в ClickHouse —
Storage Writer: консьюмер топика с батчевой вставкой по Native protocol.

Синхронный ответ SDK означает «батч принят в буфер», а не «строка лежит в ClickHouse».

## Consequences

### Позитивные

- p99 ingest не зависит от скорости ClickHouse
- Батчинг соответствует модели записи MergeTree
- Топик держит запас на несколько часов простоя Storage Writer
  ([`../../requirements.md` §1.3](../../requirements.md#13-риски-и-ограничения))

### Негативные / trade-offs

- Событие появляется в Query API с задержкой буфера, а не сразу после HTTP 200
- При длительном отказе writer события теряются после истечения retention топика —
  риск принят явно в §1.3 требований

### Риски

- Несогласованный размер/интервал батча Storage Writer снова даст мелкие INSERT —
  параметры батча фиксируются в сайзинге и контракте writer'а

## Alternatives considered

### Синхронная запись Ingest API → ClickHouse

Укладывает p99 ingest в latency OLAP-вставки и нарушает антипаттерн мелких INSERT.
Отклонено: SLO приёма и класс хранилища несовместимы с этим путём.

### Буфер без отдельного writer (Ingest пишет в Kafka и сам же вставляет в ClickHouse)

Смешивает latency-критичный HTTP-контур с батчингом OLAP. Отказ ClickHouse
блокировал бы приём либо заставлял держать второй буфер внутри Ingest.

## Links

- [`../04-solution-strategy.md` §4.1](../04-solution-strategy.md#41-архитектурный-стиль)
- Related: [ADR-0002](0002-idempotency-not-exactly-once.md), [ADR-0003](0003-query-time-vs-pre-aggregation.md)
