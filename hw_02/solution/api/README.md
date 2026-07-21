# API-контракты Bookly

Публичный edge — через API Gateway.

Внутренние gRPC описаны кратко рядом; полные `.proto` можно добавить позже.

| # | API | Протокол | Файл |
|---|---|---|---|
| 1 | Поиск объектов | GraphQL | [`search.md`](./search.md) |
| 2 | Создание бронирования | REST | [`booking-create.md`](./booking-create.md) |
| 3 | Платёж / webhook | REST | [`payment.md`](./payment.md) |
| 4 | Отмена бронирования | REST | [`booking-cancel.md`](./booking-cancel.md) |

Общие заголовки edge:

| Header | Обязателен | Описание |
|---|---|---|
| `Authorization: Bearer <jwt>` | да (кроме search public) | JWT от Identity |
| `Idempotency-Key` | для мутаций оплаты/создания брони | UUID |
| `X-Request-Id` | рекомендуется | корреляция логов |
