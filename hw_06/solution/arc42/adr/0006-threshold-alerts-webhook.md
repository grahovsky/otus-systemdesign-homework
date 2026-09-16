# ADR-0006 — Пороговый алерт по definition, доставка webhook

- **Status**: Accepted
- **Date**: 2026-09-16
- **Decision makers**: архитектор

## Context

Платформа выдаёт аналитику через Query API; интерактивный UI / BI вынесены в backlog
([`../../requirements.md` §1.4](../../requirements.md#14-backlog-что-не-входит-в-scope)).
Без активного триггера владелец узнаёт о просадке воронки или метрики только если сам
открыл запрос. Нужен минимальный сигнал «порог нарушен» при условии, что analytics
platform out of scope.

`metric_definitions` в Postgres уже есть, но ни один из четырёх query-эндпоинтов не
принимает `metricDefinitionId` — без потребителя сущность избыточна. Алерт закрывает
и эту дыру: definition становится входом правила, а не пятым аналитическим отчётом.

Варианты: (а) полноценная BI/дашборды/ML-аномалии; (б) отдельный Alert Service;
(в) периодическая проверка правил внутри Query API и HTTPS POST на `webhookUrl`
владельца.

## Decision

Владелец создаёт правило на уже существующую funnel или metric definition: условие
вида «значение упало больше чем на X% за окно Y», плюс `webhookUrl`. Query API по
расписанию (минуты, не sub-second) пересчитывает правило **тем же путём чтения**,
что синхронный query-эндпоинт (ClickHouse + definitions из App & Config), и при
срабатывании делает HTTPS POST.

CRUD правил — в App & Config, таблица `alert_rules` в PostgreSQL рядом с definitions.
Отдельный сервис не заводится: это тот же read-path Query API, запущенный по таймеру,
а не новый контур хранения или новый класс запросов.

Доставка — webhook с HMAC-подписью (`X-Telemetry-Signature`), retry с backoff;
секрет подписи не пишется в логи ([`../../security.md`](../../security.md)).

## Consequences

### Позитивные

- Владелец получает активный сигнал без BI-платформы в scope.
- `metric_definitions` получает потребителя, симметрично `funnel_definitions`.
- Нагрузка проверки — того же порядка, что уже посчитанный Query API
  ([`../../sizing.md` §1](../../sizing.md#1-расчёт-rps)): тысячи правил, редкое
  расписание, не новая RPS-статья ingest.

### Негативные / trade-offs

- Нет chart builder, когорт и «умного» anomaly detection — только явный порог.
- Доставка at-least-once: владелец должен быть идемпотентен по `(alertId, firedAt)`.
- Webhook владельца — внешний HTTP; таймаут и retry ограничены, иначе job
  блокируется медленным клиентом.

### Риски

- Бурст срабатываний на массовой просадке (много приложений сразу) давит исходящий
  HTTP Query API. Митигация: per-rule cooldown и отдельный пул исходящих соединений
  (тот же bulkhead, что на Ingest, только в обратную сторону).

## Alternatives considered

### Полноценная BI / дашборды / ML (вариант а)

Закрывает «польза владельцу» шире, но это отдельный продукт поверх метрик, прямо
противоречит §1.4 и тесту на переусложнение из [`../../requirements.md`](../../requirements.md).
Отклонено: scope creep темы.

### Отдельный Alert Service (вариант б)

Изолировал бы исходящий HTTP от Query API. Отклонено: правил тысячи, расписание
редкое, путь чтения совпадает с уже существующим Query API — отдельный контейнер
не даёт изоляции отказа, которой нет у синхронного запроса тех же definitions.

## Links

- [`../../requirements.md` §1.1.6, §1.4](../../requirements.md)
- [`../../api/alerts.md`](../../api/alerts.md)
- Related: [ADR-0003](0003-query-time-vs-pre-aggregation.md)
