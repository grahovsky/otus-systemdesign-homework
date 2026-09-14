# Схемы (PlantUML)

> Часть [решения ДЗ 6](README.md). C1/C2 — не здесь, они в [`../architecture/`](../architecture/)
> (LikeC4). Здесь — остальные схемы, только `.puml` (в репозиторий попадают только `.puml`,
> не сгенерированные `.svg`/`.png`).

| Файл | Раздел | Показывает |
|---|---|---|
| `er-data-model.puml` | [4. Хранение данных](../data-storage.md) | сущности и связи |
| `sharding.puml` | [4. Хранение данных](../data-storage.md) | ключ шардирования, распределение |
| `caching-flow.puml` | [4. Хранение данных](../data-storage.md) | поток запроса через кэш |
| `queues.puml` | [4. Хранение данных](../data-storage.md) | outbox / события между сервисами |
| `rps-fanout.puml` | [3. Сайзинг](../sizing.md) | откуда берутся запросы в сервисы (fan-out) |
| `replication-ha.puml` | [6. Надёжность](../reliability.md) | data/control/routing plane репликации |
| `dr-failover.puml` | [6. Надёжность](../reliability.md) | порядок переключения при DR |
| `auth-planes.puml` | [7. Безопасность](../security.md) | два внешних контура (API-ключ / JWT) и mTLS внутри |
| `trace-flow.puml` | [8. Observability](../observability.md) | сквозной trace: sync ingest + async запись, Query отдельно |
| `chaos-faults.puml` | [9. Тестирование](../testing.md) | точки отказа трёх chaos-экспериментов на пути записи |

Рендер: `plantuml diagrams/*.puml` или расширение PlantUML в IDE.

> **Черновые заметки (убрать перед сдачей):** аналогичные `diagrams/` — в
> [ДЗ 3](../../hw_03/solution/diagrams/) / [ДЗ 4](../../hw_04/solution/diagrams/) /
> [ДЗ 5](../../hw_05/solution/diagrams/).
