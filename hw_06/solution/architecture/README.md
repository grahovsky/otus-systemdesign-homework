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
│   ├── persons.c4        # акторы
│   ├── systems-ext.c4    # внешние системы
│   ├── core/index.c4     # TODO: переименовать по имени выбранной системы; система + контейнеры
│   └── relations-core.c4 # связи с протоколами на рёбрах
├── views/
│   ├── c1-context.c4     # System Context
│   └── c2-containers.c4  # Containers, протоколы на рёбрах
├── spec.c4
└── likec4.config.yaml
```

> `model/core/` — плейсхолдер-имя директории до выбора темы. Переименовать в домен
> (например `messenger/` или `telemetry/`) вместе с ключом системы в `.c4`-файлах.

## Как посмотреть

```bash
cd hw_06/solution/architecture
npx --yes likec4@1 dev
# или: likec4 check .
```

> **Черновые заметки (убрать перед сдачей):** структура и `spec.c4` — по образцу
> [ДЗ 2 `architecture/`](../../../hw_02/solution/architecture/).
