# Схемы (PlantUML)

> Часть [решения ДЗ 6](README.md). 
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

Рендер: `plantuml diagrams/*.puml` или расширение PlantUML в IDE.

> **Черновые заметки (убрать перед сдачей):** аналогичные `diagrams/` — в
> [ДЗ 3](../../hw_03/solution/diagrams/) / [ДЗ 4](../../hw_04/solution/diagrams/) /
> [ДЗ 5](../../hw_05/solution/diagrams/).
