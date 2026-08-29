# diagrams/

Схемы отказоустойчивости и DR Bookly.

| Схема | Файл |
|---|---|
| Репликация Tier 0 БД (Booking / Inventory / Payment) | [`replication-ha.puml`](replication-ha.puml) |

В репозиторий — только `.puml`, svg генерируются.

Локальный просмотр (PlantUML CLI / IDE-плагин / [plantuml.com](https://www.plantuml.com/plantuml)):

Рендер SVG из корня репозитория:
```bash
make HW=hw_05
```
