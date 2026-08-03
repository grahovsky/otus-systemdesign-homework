# diagrams/

Схемы хранения данных Bookly.

| Схема | Файл |
|---|---|
| ER / модель данных по сервисам | [`er-data-model.puml`](er-data-model.puml) |
| Шардирование Inventory | [`sharding-inventory.puml`](sharding-inventory.puml) |
| Шардирование Booking | [`sharding-booking.puml`](sharding-booking.puml) |
| Кэш: cache-aside + invalidate | [`caching-flow.puml`](caching-flow.puml) |
| Kafka: producers / topics / consumers | [`queues-kafka.puml`](queues-kafka.puml) |

В репозиторий — только `.puml`, svg - генерируются

Локальный просмотр (PlantUML CLI / IDE-плагин / [plantuml.com](https://www.plantuml.com/plantuml)):

Рендер SVG из корня репозитория:
```bash
make HW=hw_03
```
