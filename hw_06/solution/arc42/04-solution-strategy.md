# 4. Solution strategy

> Часть [решения ДЗ 6](../README.md).

## 4.1 Архитектурный стиль

**Событийно-ориентированная декомпозиция вокруг единого пути записи**, не классические
CRUD-микросервисы: Ingest API пишет только в Kafka, Storage Writer — единственный writer в
ClickHouse. ClickHouse — SoT сырых событий, не побочный OLAP-sink рядом с другой системой
записи: Query API читает тот же контур, куда пишет Storage Writer. Альтернатива, которая не
выбрана — **синхронная запись Ingest API → ClickHouse** без буфера: построчный/мелкий INSERT —
известный антипаттерн ClickHouse (частые мелкие вставки не сжимаются и создают избыточное
число partition-частей), и синхронная OLAP-запись привязала бы p99 ingest (< 300 мс,
[`../requirements.md`](../requirements.md)) к скорости ClickHouse под пиковой нагрузкой.

## 4.2 Декомпозиция сервисов

| # | Сервис | Ответственность | Не делает |
|---|---|---|---|
| 1 | **Ingest API** | Приём батчей, валидация схемы, gzip, идемпотентность по `event_id`, rate-limit per-app, geo/device offline-lookup | Не пишет в ClickHouse напрямую |
| 2 | **App & Config Service** | Регистрация приложений/API-ключей, per-app funnel/metric definitions, sampling/feature flags SDK | Не участвует в hot path записи событий |
| 3 | **Storage Writer** | Консьюмер Kafka → батчевая вставка в ClickHouse | Не отвечает клиенту синхронно |
| 4 | **Query API** | Funnel conversion, retention, DAU/MAU, сегменты | Не пишет события |

Инфраструктура (не считаем отдельными «бизнес-сервисами»): Kafka (`events.raw`), ClickHouse,
PostgreSQL, Redis.

**Почему 4, а не больше.** App & Config Service объединяет три обязанности (регистрация/
ключи, funnel/metric definitions, sampling) в одном контейнере: все три — CRUD-метаданные
малого объёма в Postgres с общим владельцем-актором (владелец приложения), дробление на
отдельные сервисы добавило бы межсервисные вызовы без выигрыша в изоляции отказа. Отдельный
API Gateway не заведён: у Ingest API (аутентификация по API-ключу приложения) и у App/Query
API (доступ владельца приложения) разная модель авторизации и разные клиенты — общий edge
не устраняет дублирование, а добавляет лишний прыжок на каждый запрос.

**Почему не дробим дальше.** Отдельный сервис Validation/Enrichment не выделен: валидация
схемы и geo/device lookup синхронны и дешевле внутри Ingest API, чем ещё один consumer-hop
перед Kafka. Stream processing (real-time агрегаты) вынесен в backlog
([`../requirements.md` §1.4](../requirements.md#14-backlog-что-не-входит-в-scope)) —
не нужен для четырёх query-эндпоинтов §4.2.

## 4.3 Протоколы — микс

| Ребро | Протокол | Почему |
|---|---|---|
| Mobile App + SDK → Ingest API | **HTTPS REST** | Батч событий, gzip; клиент — мобильный SDK, не внутренний сервис |
| Mobile App + SDK → App & Config Service | **HTTPS REST** | Разовый pull конфига при старте сессии, не sync-цепочка команд |
| Владелец приложения → App & Config / Query API | **HTTPS REST** | Публичный CRUD/аналитические запросы, без внутреннего RPC-контракта |
| Ingest API → App & Config Service | **HTTPS REST** | Fallback при промахе Redis: ключ, схема события, sampling. Не hot path при попадании в кэш |
| Ingest API → Storage Writer | **Kafka** (`events.raw`) | Развязка пиков записи, буфер на случай простоя writer'а, at-least-once. Ключ партиции — `app_id` по тому же directory, что шард ClickHouse ([`../data-storage.md` §3, §5](../data-storage.md)) |
| Storage Writer → ClickHouse | **Native protocol, batch insert** | Батч, а не построчный INSERT — см. §4.1 |
| Query API → App & Config Service | **HTTPS REST** | Редкие запросы за определениями воронки, не hot path |

Отдельного internal gRPC-слоя (как в Bookly) нет: между сервисами нет синхронных
многошаговых команд с ответом — каждый переход либо однонаправленный HTTP-запрос, либо
асинхронное событие.

## 4.4 Асинхронность — где и зачем

| Сценарий | Async? | Почему |
|---|---|---|
| Приём батча событий | Sync HTTPS (ответ SDK) + **async запись в хранилище** | SDK должен получить подтверждение приёма быстро (p99 < 300 мс), но не должен ждать вставки в ClickHouse |
| Запись в ClickHouse | **Async Kafka → Storage Writer** | Батчинг вставки — обязательное требование ClickHouse (§4.1), синхронная запись недостижима на нужном p99. Transient-сбой INSERT — retry-топик той же consumer group, исчерпание — DLT ([`../data-storage.md` §5](../data-storage.md#5-очереди--асинхронность-на-хранении)) |
| Fetch SDK-конфига | Sync HTTPS | Конфиг нужен SDK перед стартом сессии, ответ короткий (Postgres-lookup) |
| Промах кэша ключа/конфига на ingest | Sync HTTPS к App & Config | Cache-aside: Ingest читает Redis; при промахе запрашивает App & Config и пишет в Redis с TTL. Push из App & Config в Redis не используется |
| Query API запросы | Sync HTTPS | Владелец приложения ждёт результат в дашборде; latency бюджет — p95 < 2 с, не требует async-паттерна |
| Дедуп/rate-limit на ingest | Sync, но локально к Redis | Проверка `event_id`/лимита — не блокирующий сетевой вызов к другому сервису |
