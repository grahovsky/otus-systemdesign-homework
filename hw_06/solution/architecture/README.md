# Архитектура (LikeC4)

> Часть [решения ДЗ 6](../README.md), раздел 2 (Концептуальная архитектура).

Source of truth для C1/C2. Рендер — [LikeC4](https://likec4.dev).

Связь с arc42:
- **§1** — [`../arc42/01-introduction.md`](../arc42/01-introduction.md)
- **§4** — [`../arc42/04-solution-strategy.md`](../arc42/04-solution-strategy.md)
- **§5** — этот каталог (views)
- **§9** — [`../arc42/adr/`](../arc42/adr/)

## Структура

```
architecture/
├── model/
│   ├── persons.c4          # актор: владелец приложения
│   ├── systems-ext.c4      # внешняя система: Mobile App + SDK
│   ├── telemetry/index.c4  # система Telemetry + контейнеры
│   └── relations-core.c4   # связи с протоколами на рёбрах
├── views/
│   ├── c1-context.c4       # System Context
│   └── c2-containers.c4    # Containers, протоколы на рёбрах
├── spec.c4
└── likec4.config.yaml
```

## Состав C2

Минимально рабочий контур: регистрация приложения → SDK получает конфиг → приём событий →
хранение → аналитика. Без отдельного API Gateway — у Ingest API (аутентификация по API-ключу
приложения) и у App/Query API (доступ владельца приложения) разная аутентификация и разные
клиенты, общий edge не оправдан на этом объёме сервисов.

| Контейнер | Ответственность |
|---|---|
| **Ingest API** | Приём батчей событий от SDK: валидация схемы, gzip, идемпотентность по `event_id`, rate-limit per-app, geo/device offline |
| **App & Config Service** | Регистрация приложений/API-ключей, per-app funnel/metric definitions, sampling/feature flags для SDK |
| **Storage Writer** | Консьюмер Kafka → батчевая вставка в ClickHouse |
| **Query API** | Funnel conversion, retention, DAU/MAU, сегменты |
| **Kafka** | Буфер `events.raw` между Ingest API и Storage Writer |
| **ClickHouse** | SoT сырых событий |
| **PostgreSQL** | Метаданные App & Config Service |
| **Redis** | Кэш API-ключей/конфига на hot path Ingest API, дедуп-окно `event_id`, счётчики rate-limit per-app |

## Как посмотреть

```bash
cd hw_06/solution/architecture
npx --yes likec4@1 dev
# или: likec4 check .
```
