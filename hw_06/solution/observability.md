# 8. Observability

> Часть [решения ДЗ 6](README.md). Система: сервис телеметрии мобильных приложений
> (контейнеры — [`architecture/`](architecture/), нагрузка — [`sizing.md`](sizing.md),
> хранилища — [`data-storage.md`](data-storage.md)). Схема трейса —
> [`diagrams/trace-flow.puml`](diagrams/trace-flow.puml).

Критичный путь — приём батча и доставка в ClickHouse, не дашборд: потеря события на Ingest
или до вставки в SoT необратима, простой Query только откладывает чтение
([`reliability.md` §1](reliability.md#1-rto--rpo-по-сервисам)). RED — на Ingest, Storage
Writer и Query API; USE — на Kafka, ClickHouse и Redis под ними; бизнес-метрики — по
[G1–G3](arc42/01-introduction.md). App & Config и PostgreSQL в таблицу не вынесены:
пользовательский симптом их деградации ловится через Ingest (ADR-0005, stale-кэш) и Query
(нет definitions — 5xx), а не отдельным RED на CRUD метаданных. CPU/RAM инстансов
собираются стандартными exporter'ами — не проходят тест «что предпринять» лучше, чем 14
метрик ниже.

## 1. Ключевые метрики

Каждая строка — с действием при превышении порога; runbook — в [п.2](#2-алерты).

| # | Сервис / ресурс | Метод | Метрика | Как меряем | Зачем (что покажет) и что предпринимаем |
|---|---|---|---|---|---|
| 1 | Ingest API | RED Rate | HTTP RPS батчей и событий/с, label `app_id` | counter запросов и `accepted` событий | HTTP ≠ throughput: средний батч 10 событий ([`sizing.md` A1](sizing.md)). Рост виден раньше p99. Устойчивый поток сверх пика 1 111 HTTP / 11 111 соб/с — масштабировать Ingest (ёмкость 400 RPS/инстанс). Доля одного `app_id` → 2% — hotspot записи, не общий RPS |
| 2 | Ingest API | RED Errors | 4xx / 429 отдельно от 5xx и таймаутов | counter по классу status и `code` (`SCHEMA_VIOLATION`, `RATE_LIMITED`, `INVALID_API_KEY`) | 5xx — наша авария (откат деплоя / зависимость). 422 — клиентская схема, не кластер. 429 на одном `app_id` — bulkhead сработал, не нехватка парка ([`reliability.md` §3](reliability.md#3-паттерны-отказоустойчивости)) |
| 3 | Ingest API | RED Duration | p50 / p95 / **p99** ответа `POST /v1/events` | histogram, SLO p99 < 300 мс | хвост, который видит SDK; среднее его прячет. p99 выше SLO — SDK уходит в ретраи и усиливает нагрузку; смотреть produce в Kafka vs Redis vs fallback App & Config |
| 4 | Storage Writer | RED Rate | событий INSERT/с в ClickHouse | counter строк успешного батча | расхождение с #1 — батчи лежат в `events.raw`, ещё не в SoT. Если Writer жив, но rate ниже ingest — смотреть lag (#8) и parts (#10), не масштабировать Ingest |
| 5 | Storage Writer | RED Errors | transient retry vs **DLT** отдельно | counter по топику `events.raw.storage-writer.retry` / `.dlt` | retry — ожидаемый backoff. DLT — принятый батч исчерпал попытки и не в SoT; разбор poison vs деградация ClickHouse, затем replay ([`data-storage.md` §5](data-storage.md#5-очереди--асинхронность-на-хранении)) |
| 6 | Query API | RED Duration | p95 по эндпоинту (funnel / retention / segments / dau-mau) | histogram, SLO p95 < 2 с | G1. Рост на одном `appId` — hotspot-скан (~36 ГБ сжатых, ~7 с, [`sizing.md` §5](sizing.md#5-оптимизация)), не парк Query. Рост на всех — saturation ClickHouse (#10) |
| 7 | Query API | RED Errors | 5xx и таймауты; пустой результат — не ошибка | counter по status; «нет событий за период» — 200 | как отказ выдачи, а не «нет данных». 5xx — ClickHouse или App & Config (definitions); пустой ряд воронки — ожидаемое поведение |
| 8 | Kafka `events.raw` | USE Saturation | consumer lag группы Storage Writer, сек | Kafka exporter, per partition | ведущий индикатор до потери: retention 12 ч — потолок, после которого принятое событие не восстановить ([`requirements.md` §1.3](requirements.md#13-риски-и-ограничения)). Растущий lag — масштабировать Writer / лечить INSERT, не ждать 12 ч |
| 9 | Kafka DR | USE Saturation | лаг межкластерной репликации, сек | MirrorMaker 2 / Cluster Linking lag | фактический RPO при DR vs бюджет ≤ 5 мин ([`reliability.md` §1](reliability.md#1-rto--rpo-по-сервисам)). Рост — канал/CPU брокеров региона B, не ingest |
| 10 | ClickHouse | USE Saturation | parts pending merge + lag реплики шарда при `insert_quorum=2` | `system.parts` / `system.replicas` | мелкие parts — антипаттерн INSERT и причина роста p95 Query. Lag реплики шарда — локальный RPO ≈ 0 под угрозой ([`reliability.md` §2](reliability.md#2-репликация-критичных-хранилищ)): Writer начнёт получать отказ кворума |
| 11 | Redis | USE Utilization / Errors | память окна `event_id` + eviction rate этого keyspace | redis exporter, label по префиксу `event:` | слот 32 ГБ задан так, чтобы LRU на окне дедупа в штате не срабатывал ([`data-storage.md` §4](data-storage.md#4-кэширование)). Eviction раньше TTL 6 ч — дубли проходят в Kafka; второй барьер — идемпотентный INSERT, но нагрузка на Writer растёт |
| 12 | Ingest (бизнес, G2) | Бизнес | принятые события/мин (`202`, сумма `accepted`) | counter `accepted` с ответа батча | прямая ценность платформы: просадка видна раньше жалоб владельца SDK. Не путать с HTTP RPS (#1) и с INSERT (#4) |
| 13 | Storage Writer (бизнес, G1) | Бизнес | freshness: p95 задержки `received_at` → строка в `events` | histogram на Writer в момент INSERT | «данные появились в дашборде». Горизонт аналитики — часы/дни, порог наблюдения — минуты (flush 2 с, [`sizing.md` A11](sizing.md)), не 12 ч retention. Алерт — по lag (#8), не по этой гистограмме: иначе два уведомления на одну причину |
| 14 | Ingest / Writer (бизнес, G3) | Бизнес | доля дублей (`duplicates` / принятые) и DLT rate | counter `duplicates` на Ingest; #5 на Writer | штатный повтор SDK внутри окна дедупа — ожидаемо. Рост `duplicates` без роста ретраев клиента — сломанный SET NX. Рост DLT — не «дубль», а потеря пути в SoT |

## 2. Алерты

Семь алертов сформулированы как пользовательский или платформенный симптом (SDK не может
сдать батч; принятые события не попадут в SoT; дашборд не отвечает за 2 с), а не как
загрузка CPU. Для одного инцидента — один алерт: freshness (#13) и CPU Writer на
отдельные правила не вынесены, их закрывают #3 и метрика #8. Каждый опирается на строку из
[п.1](#1-ключевые-метрики) и на механизм из [`reliability.md`](reliability.md).

Порог ошибок Ingest (0.5% / 3 мин) жёстче 2% из Bookly-аналога: SLO приёма 99.9%, а не
99.5% ([`requirements.md` §1.2](requirements.md#12-нефункциональные-требования)). При 0.5%
ошибок темп жжёт 30-дневный бюджет 0.1% с коэффициентом ×5; окно 3 мин отсекает разовый
всплеск, но ещё оставляет запас до исчерпания бюджета.

```
Название:        Рост ошибок приёма (Ingest)
Условие/порог:   доля 5xx + таймаутов на POST /v1/events > 0.5% за 3 мин
                 (метрика #2; 4xx/429 не входят)
Severity:        critical
Что означает:    часть SDK не может сдать батч — события выпадают из воронки
                 безвозвратно (Tier 0)
Вероятная причина: сломанный релиз Ingest, недоступность Kafka/Redis, исчерпание
                 пула к producer или к Redis
Реакция:         последний деплой Ingest → откатить, если недавний → health
                 Kafka (ISR) и Redis → utilization пулов produce / Redis
                 ([`reliability.md` §3](reliability.md#3-паттерны-отказоустойчивости))
Кому:            on-call backend (Ingest)
```

```
Название:        p99 ingest выше SLO
Условие/порог:   p99 POST /v1/events > 300 мс в течение 5 мин (метрика #3).
                 Critical, если одновременно растут 5xx (#2)
Severity:        warning (critical при совместном росте ошибок)
Что означает:    SDK не укладывается в бюджет ответа и повторяет батч —
                 ретраи усиливают нагрузку на уже медленный путь
Вероятная причина: медленный produce в Kafka, насыщение Redis (ключ/дедуп/лимит),
                 fallback к App & Config при промахе кэша (ADR-0005)
Реакция:         разбить latency по спанам Redis / Kafka / fallback App & Config
                 ([п.3](#3-логи-и-трейсы)) → если stale-режим — не трогать Ingest,
                 лечить App & Config; если produce — ISR Kafka
Кому:            on-call backend (Ingest)
```

```
Название:        Lag Storage Writer растёт
Условие/порог:   consumer lag группы Writer > 15 мин и растёт 5 мин подряд —
                 warning; > 2 ч либо > 50% retention топика (6 ч из 12) — critical
                 (метрика #8)
Severity:        warning → critical
Что означает:    батчи приняты (HTTP 202), но ещё не в SoT. 15 мин — уже на два
                 порядка выше штатного flush 2 с; 6 ч — половина окна, после
                 которого событие потеряется вместе с retention Kafka
Вероятная причина: Writer не успевает (деградация INSERT, рост parts #10),
                 упали консьюмеры, всплеск потока сверх 11 111 соб/с
Реакция:         health Writer → если живы, но не догоняют: parts/кворум
                 ClickHouse (#10) → масштабировать CG по партициям шарда →
                 не масштабировать Ingest (он уже принял)
Кому:            on-call backend (Storage Writer)
```

```
Название:        Рост DLT Storage Writer
Условие/порог:   появление сообщений в `events.raw.storage-writer.dlt`
                 устойчиво 5 мин (метрика #5)
Severity:        critical
Что означает:    принятый батч исчерпал retry и не будет вставлен штатным
                 консьюмером — события не попадут в SoT, пока ops не сделает replay
Вероятная причина: poison-batch (схема/неожиданный payload), устойчивый отказ
                 INSERT (диск, кворум реплики шарда), баг Writer
Реакция:         образец сообщения в DLT → схема vs отказ ClickHouse →
                 если CH жив — replay в main после фикса (дедуп по `event_id`,
                 [ADR-0002](arc42/adr/0002-idempotency-not-exactly-once.md));
                 main соседних партиций не останавливать
Кому:            on-call backend (Storage Writer)
```

```
Название:        p95 Query API выше SLO
Условие/порог:   p95 любого аналитического эндпоинта > 2 с в течение 5 мин
                 (метрика #6)
Severity:        warning
Что означает:    владелец не получает воронку/retention в бюджете дашборда.
                 Не critical: Query — 99.5%, простой не теряет события
                 ([`reliability.md` §1](reliability.md#1-rto--rpo-по-сервисам))
Вероятная причина: скан hotspot-приложения (2% потока, ~7 с на 36 ГБ,
                 [`sizing.md` §5](sizing.md#5-оптимизация)) либо общее
                 насыщение шарда (parts #10)
Реакция:         p95 в разбивке по `appId` → один клиент: sampling / точечная
                 pre-aggregation, не смена шарда для всех (ADR-0003/0004) →
                 все клиенты шарда: parts/CPU ClickHouse
Кому:            on-call backend (Query API)
```

```
Название:        Лаг Kafka DR-реплики выше порога
Условие/порог:   лаг MirrorMaker 2 / Cluster Linking `events.raw` > 30 с,
                 2 мин подряд (метрика #9)
Severity:        warning (critical, если лаг растёт дольше 10 мин)
Что означает:    фактический RPO при региональном DR сейчас хуже бюджета
                 ≤ 5 мин: авария в этот момент потеряет больше ещё не
                 вставленных в CH событий, чем заложено
Вероятная причина: межрегиональный канал, отставание брокеров региона B
Реакция:         канал и CPU брокеров B → если не догоняет — эскалация Ops,
                 риск-оценка для Incident Commander до объявления DR
                 ([`reliability.md` §4](reliability.md#4-план-dr))
Кому:            on-call Ops
```

```
Название:        Eviction окна дедупа Redis
Условие/порог:   eviction ключей `event:{app_id}:{event_id}` > 0 в течение 5 мин
                 (метрика #11)
Severity:        warning
Что означает:    повтор SDK после таймаута проходит в Kafka как новое сообщение —
                 риск дублей в сырье до второго барьера в ClickHouse (G3).
                 В штате LRU на этом окне не срабатывает (слот 32 ГБ)
Вероятная причина: рост потока / удлинение окна, утечка чужого keyspace,
                 слот меньше расчётного
Реакция:         used_memory vs расчёт пика 19 ГБ ([`sizing.md` A9](sizing.md)) →
                 вытесняется ли только `event:` или кэш ключей → не чистить
                 дедуп вручную (вырастет число дублей); при нехватке — слот 64 ГБ,
                 не укорачивать TTL ниже retry-budget SDK
Кому:            on-call backend (Ingest)
```

**Таблица-сводка**

| Алерт | Порог | Severity | Симптом | Реакция |
|---|---|---|---|---|
| Ошибки приёма Ingest | 5xx+timeout > 0.5% / 3 мин | critical | SDK не сдаёт батч, события теряются | откат деплоя / Kafka / Redis |
| p99 ingest выше SLO | p99 > 300 мс / 5 мин | warning→critical | ретраи SDK, нагрузка растёт | спаны Redis vs Kafka vs App & Config |
| Lag Storage Writer | > 15 мин растёт; critical > 2 ч или > 6 ч | warning→critical | 202 есть, в SoT нет; дальше — потеря | health Writer, parts CH, scale CG |
| Рост DLT | DLT > 0 / 5 мин | critical | принятый батч не вставится сам | разбор poison, replay с дедупом |
| p95 Query выше SLO | p95 > 2 с / 5 мин | warning | дашборд не укладывается в 2 с | hotspot `appId` vs шард CH |
| Лаг Kafka DR | > 30 с / 2 мин | warning→critical | RPO DR хуже ≤ 5 мин | канал в регион B, эскалация Ops |
| Eviction окна дедупа | eviction `event:` > 0 / 5 мин | warning | ретраи SDK дают дубли в сырье | память vs расчёт, не чистить окно |

## 3. Логи и трейсы

Батч проходит синхронный путь (SDK → Ingest → Redis → produce в Kafka → `202`) и
продолжается асинхронно (Storage Writer → INSERT в ClickHouse). HTTP 202 означает «в
буфере», не «строка в SoT» ([ADR-0001](arc42/adr/0001-batch-insert-clickhouse.md)). Без
сквозного `trace_id` на обоих отрезках «событие принято, но не в воронке» распадается на
два несвязанных фрагмента — схема: [`diagrams/trace-flow.puml`](diagrams/trace-flow.puml).

**Логи** — структурированный JSON. Обязательные поля каждой записи: `timestamp`,
`service` + `instance`, `severity`, `trace_id` / `span_id`, `request_id`, `app_id`.
`request_id` — значение `X-Request-Id` ([`api/README.md`](api/README.md)); если SDK его не
прислал, Ingest генерирует. На входе Ingest `trace_id` совпадает с `request_id`, чтобы не
плодить второй идентификатор на тот же HTTP-запрос. Предметные
поля — `batch_id` и число событий (`accepted` / `duplicates` / `rejected`); сами
`event_id` батча (до 50) в лог не пишем — кардинальность, без выигрыша для поиска по
`batch_id`.

Не логируем: plaintext API-ключа и JWT, сырой IP, тело `properties` события — то же
сокращение поверхности, что в [`security.md`](security.md). `user_id` в логе ingest не
нужен: воронка строится в ClickHouse, а не по логам.

| Сервис | Что логируем |
|---|---|
| Ingest API | route, status, latency, `batch_id`, `accepted`/`duplicates`/`rejected`, cache hit / stale (ADR-0005), hash ключа — не plaintext |
| Storage Writer | размер батча (событий), шард `app_id`, длительность INSERT, исход: success / retry / DLT |
| Query API | эндпоинт, `appId`, bytes scanned / elapsed; без строк результата и без JWT |
| **Аудит** (отдельный поток, дольше TTL обычных логов) | ротация/отзыв API-ключа, смена `event_schema` / definitions / alert-правил, исходящий webhook (alertId, status, без секрета и без тела) — кто/когда/какой `app_id`; нужно для разбора «почему батч стал 422», окна revoke 5–30 мин и повторных срабатываний алерта |

**Трейсы.** Синхронный путь одним trace: Ingest → Redis (lookup ключа, дедуп, rate-limit) →
produce в Kafka. Контекст (W3C `traceparent`) кладётся в заголовки сообщения `events.raw`.
Storage Writer продолжает тот же trace на consume → batch INSERT. Без переноса в заголовки
асинхронный разрыв выглядел бы как новый корневой спан, и сопоставление «202 vs нет строки
в `events`» свелось бы к ручному поиску по `batch_id` и времени.

Отдельные спаны — на то, что уже в метриках: Redis vs Kafka produce (разбор p99, метрика
#3), INSERT Writer (метрики #4/#10), скан Query с тегом `appId` (метрика #6). Открытие
circuit breaker к App & Config — тег спана: по ingest-запросу сразу видно, что ответ
ушёл из stale-кэша (breaker открыт), без склейки логов.

Query API — **отдельный** trace: другой актор (владелец, JWT), другой момент времени.
Склеивать дашборд с батчем SDK по `trace_id` нельзя и не нужно; корреляция с ingest — по
`app_id` и окну `received_at`.

**Sampling.** В Bookly-аналоге write-путь саги держали на 100%: там ~25 RPS записи. Здесь
пик Ingest — 1 111 HTTP ([`sizing.md` §1](sizing.md#1-расчёт-rps)); 100% успешных батчей
оплачивали бы трассировку каждого produce без выигрыша для разбора инцидента.

| Что | Доля | Почему |
|---|---|---|
| Ошибки (5xx, таймаут) на любом сервисе | 100% | разбор как раз нужен |
| Retry и DLT Writer | 100% | редкий путь, цена полной выборки ничтожна |
| Успешный ingest (`202`) | 1–5% | достаточно профиля p99 (#3) при 1 111 RPS |
| Query API | 100% | ~3 RPS в пике — дешевле, чем терять скан hotspot |

Head-based: решение о выборке — на корневом спане Ingest; Writer наследует флаг из
`traceparent` и не сэмплирует заново (иначе асинхронное продолжение пропало бы как раз на
тех батчах, которые попали в 1–5%). Ошибка на Writer повышает приоритет и экспортирует
хвост независимо от флага корня — иначе DLT успешного (с точки зрения SDK) батча не имел
бы трейса ingest.
