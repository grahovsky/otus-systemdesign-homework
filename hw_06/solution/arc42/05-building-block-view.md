# 5. Building block view

> Часть [решения ДЗ 6](../README.md). Источник правды — LikeC4 в
> [`../architecture/`](../architecture/); здесь — 1–2 предложения на каждый компонент.

## Level 1 — System Context (C1)

Чёрный ящик Telemetry + акторы + внешние системы.

- View: [`../architecture/views/c1-context.c4`](../architecture/views/c1-context.c4) (`telemetry-c1`)
- Система: [`../architecture/model/telemetry/index.c4`](../architecture/model/telemetry/index.c4)

| Актор / система | Роль |
|---|---|
| Владелец приложения (person) | Регистрирует приложение и API-ключи, настраивает funnel/metric definitions и sampling, читает аналитику |
| Mobile App + SDK (external system) | Технический источник событий: батчит и отправляет события, тянет конфиг sampling/feature flags |

## Level 2 — Containers (C2)

Сервисы, Kafka, хранилища, протоколы на рёбрах.

- View: [`../architecture/views/c2-containers.c4`](../architecture/views/c2-containers.c4) (`telemetry-c2`)
- Связи: [`../architecture/model/relations-core.c4`](../architecture/model/relations-core.c4)

### Компоненты (кратко)

| Контейнер | Роль |
|---|---|
| Ingest API | Приём батчей событий от SDK (HTTPS REST, gzip), валидация схемы, идемпотентность по `event_id`, rate-limit per-app, geo/device offline-lookup. Публикует в Kafka, в ClickHouse не пишет |
| App & Config Service | Регистрация приложений/API-ключей, per-app определения воронок/метрик, sampling rate и feature flags для SDK |
| Storage Writer | Консьюмер Kafka → батчевая идемпотентная вставка в ClickHouse |
| Query API | Funnel conversion, retention, DAU/MAU, сегменты — query-time по сырым событиям ClickHouse |
| Kafka (`events.raw`) | Буфер между Ingest API и Storage Writer, сглаживает пики записи, at-least-once |
| ClickHouse | SoT сырых событий (TTL 90 дней) + материализованные представления DAU/MAU (retention 2 года) |
| PostgreSQL | Метаданные App & Config Service: приложения, API-ключи, определения воронок/метрик, sampling/feature flags |
| Redis | Кэш API-ключей/конфига на hot path Ingest API, дедуп-окно `event_id`, счётчики rate-limit |

## Как посмотреть

```bash
cd hw_06/solution/architecture
npx --yes likec4@1 dev
```
