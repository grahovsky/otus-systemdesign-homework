# ДЗ 6. Проектная работа — решение

> Условие: [../Задание.md](../Задание.md).

> Новая система, **отличная** от выбранной в ДЗ 2–5 (Bookly).

## Выбранная тема

Сервис телеметрии мобильных приложений.

Решение разложено на отдельные файлы по разделам задания, а не сведено в один README.

## Структура решения

| Раздел задания | Файл / директория |
|---|---|
| 1. Требования | [`requirements.md`](requirements.md) |
| 2. Концептуальная архитектура — C4 | [`architecture/`](architecture/) (LikeC4) |
| 2. Концептуальная архитектура — arc42/ADR | [`arc42/`](arc42/) |
| 3. Сайзинг | [`sizing.md`](sizing.md) |
| 4. Хранение данных | [`data-storage.md`](data-storage.md) |
| 5. Взаимодействие — API-контракты | [`api/`](api/) |
| 6. Надёжность (RTO/RPO, репликация, DR) | [`reliability.md`](reliability.md) |
| 7. Безопасность | [`security.md`](security.md) |
| 8. Observability | [`observability.md`](observability.md) |
| 9. Тестирование | [`testing.md`](testing.md) |
| Схемы (не-LikeC4, `.puml`) | [`diagrams/`](diagrams/) |

Раздел 5 (схема взаимодействия сервисов, протоколы на рёбрах) закрывается C2-видом в
[`architecture/views/`](architecture/views/) — отдельного файла для него не заводим.

> **Черновые заметки (убрать перед сдачей):** черновик ориентируется на структуру и приёмы
> ДЗ 2–5 (Bookly) как на образец. Ссылки-подсказки для себя — ниже, по разделам:
> [ДЗ 2 `architecture/`](../../hw_02/solution/architecture/) и [`arc42/`](../../hw_02/solution/arc42/) —
> формат C4/ADR; [ДЗ 3 README](../../hw_03/solution/README.md) — формат раздела хранения данных;
> [ДЗ 4 README](../../hw_04/solution/README.md) — формат сайзинга; [ДЗ 5 README](../../hw_05/solution/README.md) —
> формат надёжности/безопасности/observability/тестирования (§1–4, §10–11, §5–7, §8–9
> соответственно); [ДЗ 2 `api/`](../../hw_02/solution/api/) — формат API-контрактов;
> [диаграммы ДЗ 3](../../hw_03/solution/diagrams/)/[ДЗ 4](../../hw_04/solution/diagrams/)/[ДЗ 5](../../hw_05/solution/diagrams/) —
> формат `diagrams/`. Финальная версия должна быть самодостаточной, без опоры на эти отсылки.

## Как читать

1. [`requirements.md`](requirements.md) — что строим и с какими цифрами.
2. [`architecture/`](architecture/) + [`arc42/`](arc42/) — контекст, контейнеры, ADR.
3. [`sizing.md`](sizing.md) → [`data-storage.md`](data-storage.md) — расчёты и следующий
   из них выбор хранилищ/шардирования/кэша.
4. [`api/`](api/) — контракты между сервисами и клиентами.
5. [`reliability.md`](reliability.md), [`security.md`](security.md),
   [`observability.md`](observability.md), [`testing.md`](testing.md) — эксплуатационный
   контур поверх готовой архитектуры.
