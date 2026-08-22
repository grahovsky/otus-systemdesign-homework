# diagrams/

Сайзинг Bookly: нагрузка и трафик. Ресурсы/деньги — таблицы в [`../README.md`](../README.md).

| Схема | Файл |
|---|---|
| Fan-out: поиск vs бронь | [`rps-fanout.puml`](rps-fanout.puml) |
| Трафик наружу: API vs CDN/фото | [`egress-cdn.puml`](egress-cdn.puml) |

В репозиторий — только `.puml`, svg — генерируются.

Рендер SVG из корня репозитория:
```bash
make HW=hw_04
```
