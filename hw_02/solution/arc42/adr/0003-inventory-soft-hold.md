# ADR-0003 — Soft-hold инвентаря с TTL

- **Status**: Accepted
- **Date**: 2026-07-12
- **Decision makers**: grahovsky

## Context

Два гостя не должны оплатить один и тот же последний номер.
Долгая жесткая блокировка без оплаты убивает конверсию и создаёт «мёртвые» слоты.

## Decision

Inventory — **единственный writer** слотов доступности.

На старте брони: **soft-hold** на слот(ы) с **TTL (15 мин)** и `hold_id`.
- Успешная оплата → Booking вызывает `Confirm(hold_id)` (hold → sold)
- Cancel / failed pay → Booking вызывает `Release(hold_id)`
- Истечение TTL → **Inventory sweeper** release + событие `inventory.released`
  → Booking переводит бронь в **EXPIRED** (не наоборот: Inventory не слушает `booking.*`)

Оптимистичная проверка доступности в Search **не резервирует** — только Inventory.

## Consequences

### Позитивные

- Снижение overbooking без 2PC
- Слоты не зависают навечно при брошенных корзинах

### Негативные / trade-offs

- Гость может «потерять» hold по TTL на экране оплаты — нужен UX таймер
- Eventual: Search может кратко показывать слот, который уже held

### Риски

- Часы/TTL drift между Redis index и PostgreSQL — source of truth = PostgreSQL,
  Redis только ускоряет lookup

## Alternatives considered

### Списание слота только после оплаты (без hold)

Выше риск double-sell при гонке двух оплат.

### Pessimistic lock на всё время checkout без TTL

Деградация доступности и злоупотребления «забронировал и ушёл».

## Links

- Related: ADR-0002
