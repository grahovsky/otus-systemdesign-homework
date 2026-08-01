# Архитектура Bookly (LikeC4)

Source of truth для C1/C2. Рендер — [LikeC4](https://likec4.dev).

Связь с arc42:
- **§4** — [`../arc42/04-solution-strategy.md`](../arc42/04-solution-strategy.md)
- **§5** — этот каталог (views)
- **§9** — [`../arc42/adr/`](../arc42/adr/)

## Структура

```
architecture/
├── model/          # persons, systems-ext, booking/, relations-core
├── views/          # c1-context, c2-containers
├── spec.c4
└── likec4.config.yaml
```

## Как посмотреть

```bash
cd hw_02/solution/architecture
npx --yes likec4@1 dev
# или: likec4 check .
```