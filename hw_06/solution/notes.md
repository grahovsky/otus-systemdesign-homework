# Черновик — Сервис телеметрии мобильных приложений

> Рабочие заметки для наполнения `requirements.md` / `arc42/` / `architecture/` в следующей
> итерации. Не финальный текст, ссылки на другие ДЗ здесь допустимы.

## Формулировка темы (для наставника/титульника)

«Сервис телеметрии мобильных приложений» — мобильная product-аналитика: SDK → ingest →
ClickHouse, воронки / retention / crash-free. **Не** APM и не общие логи.

## Сужение scope (главный риск — не домен, а scope creep)

**В scope:**
- Приём событий от мобильного SDK (батчами)
- Воронки (funnel), retention, DAU/MAU, сегменты — 3–4 query API
- Определения воронок/метрик — конфигурируются per-app

**Явно вне scope → backlog (с причиной, не просто список):**
- ML-рекомендации, anomaly detection — отдельный продукт, не ядро аналитики
- Real-time dashboards с sub-second latency — усложняет stream-слой без выигрыша для coursework
- APM / трейсинг производительности приложения — другой домен (не product-события)
- Crash reporting как отдельная фича (если не станет ядром темы) — либо явно НЕ берём, либо
  сузить тему до него отдельно; не смешивать с funnel-аналитикой в одном MVP

Тест на переусложнение: если фича не укладывается в цепочку `SDK → ingest → ClickHouse →
query API`, она в backlog.

## Основные сервисы (draft-состав)

| # | Сервис | Ответственность | Протокол in/out |
|---|---|---|---|
| 1 | **Ingest API** | Приём батчей событий от SDK, валидация схемы, gzip | HTTP REST (SDK →), публикует в Kafka |
| 2 | **Validation / Enrichment** | Схема события, geo/device lookup, dedup по `event_id` | consumer Kafka → producer Kafka (обогащённый топик) |
| 3 | **Stream processing** *(опционально на MVP)* | Real-time агрегаты (текущий DAU и т.п.) | Kafka → Kafka/ClickHouse; Flink/ksqlDB — под вопросом, может не влезть в scope |
| 4 | **Storage writer** | Консьюмер Kafka → батчевая вставка в ClickHouse | Kafka → ClickHouse (batch insert) |
| 5 | **Query/API service** | Воронки, retention, DAU/MAU, сегменты — читает ClickHouse | REST/GraphQL (клиент разработчика) → ClickHouse |
| 6 | **SDK config service** | Feature flags / sampling rate для клиентских SDK | REST (SDK →), читает Postgres |

Открытый вопрос для следующей итерации: нужен ли **Project/App management** сервис отдельно
(регистрация приложений, API keys) или это часть SDK config service — по объёму, скорее
всего, один маленький сервис на двоих.

## Хранение

| Хранилище | Роль | Что именно |
|---|---|---|
| **ClickHouse** | Ядро, SoT сырых событий | `events` (MergeTree, партиция по дате, `ORDER BY (app_id, event_time)`), TTL по retention |
| **Kafka** | Буфер ingest → ClickHouse | Сглаживает пики, at-least-once, точка для идемпотентной вставки по `event_id` |
| **PostgreSQL** | Метаданные, не события | Проекты/приложения, definitions воронок, API keys — маленький объём, нужен ACID |
| **Redis** | Вспомогательный | Дедуп-окно недавних `event_id`, rate limit по `app_id` — не SoT |

## Кандидаты в ADR (2–3 нужно выбрать для финала)

1. **Батч-вставка vs построчная в ClickHouse** — построчный INSERT не годится (частые мелкие
   вставки — антипаттерн ClickHouse), нужен буфер (Kafka + writer с батчингом по
   размеру/интервалу).
2. **Идемпотентность вместо exactly-once** — exactly-once на клиенте недостижим (SDK может
   ретраить после таймаута); решение — идемпотентная вставка/дедуп по `event_id`, а не попытка
   гарантировать ровно одну доставку на транспорте.
3. **Pre-aggregation (materialized views) vs query-time агрегация на сырых событиях** —
   trade-off latency запроса voронки vs стоимость поддержки доп. агрегатов; для MVP, вероятно,
   query-time на сырых данных + один materialized view под самый частый запрос (DAU/MAU).

## Заметки для сайзинга

- Единица измерения — events/day × средний размер события; ClickHouse даёт сжатие в разы
  относительно строчных СУБД (column-store compression) — стоит явно показать в расчётах.
- Кардинальность событий/атрибутов — отдельный риск для ClickHouse (много уникальных
  `user_id`/custom properties → хуже сжатие и медленнее запросы); зафиксировать явное
  ограничение на набор атрибутов события в требованиях.
- Пики нагрузки — вероятно, привязаны к времени суток пользователей приложения, не к сезону —
  свой профиль peak factor, считать от собственных допущений, не переносить чужой множитель.

## Риски / обоснование выбора темы (для защиты, не в финальный документ)

- Домен концептуально небольшой: 5 понятий (событие, сессия, воронка, retention,
  сэмплирование) — глубина проработки должна быть в декомпозиции и trade-off'ах, не в объёме
  доменных терминов.
- Основной риск — не домен, а scope creep (см. backlog выше); держать жёстко 4 query API.
- ClickHouse как SoT, не как побочный OLAP-sink, — ключевая новизна темы; так и подчеркнуть в
  arc42 solution strategy.

## TODO на следующую итерацию

- [ ] Перенести сужение scope → `requirements.md` §1.1/1.4 (backlog)
- [ ] Финализировать состав сервисов (решить судьбу Stream processing и
      Project/App management) → `arc42/04-solution-strategy.md` §4.2
- [ ] Проставить акторов (разработчик/владелец приложения, SDK как источник, admin?) →
      `architecture/model/persons.c4`
- [ ] Переименовать `architecture/model/core/` → `architecture/model/telemetry/`
- [ ] Выбрать 2–3 ADR из кандидатов выше → `arc42/adr/`
- [ ] Нефункциональные требования цифрами (events/day, retention период, latency query API) →
      `requirements.md` §1.2 — это же входные данные для `sizing.md`
