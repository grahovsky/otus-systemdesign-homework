# ДЗ 1. Анализ референсной архитектуры — решение

> Условие: [../Задание.md](../Задание.md) · Чек-лист: [../Чеклист.md](../Чеклист.md)  
> Схемы: [diagrams/](diagrams/)

## Выбранная архитектура

**Видеостриминг** (YouTube / Netflix) — занятие 4: кодирование, CDN, адаптивный стриминг

---

## 0. Контекст системы

**Что делает система:** принимает видеоконтент (upload или live), обрабатывает его в десятки вариантов (resolution × codec × temporal chunks), хранит и доставляет зрителям с адаптивным качеством под пропускную способность канала.

**Акторы:**

| Актор | Зачем обращается |
|-------|------------------|
| Зритель | VOD (видео по запросу) и live на Smart TV, mobile, web, console |
| Создатель контента (UGC — пользовательский контент) | Загрузка видео (YouTube) или RTMP-трансляция (Twitch) |
| Контент-партнёр | Поставка мастер-файлов ProRes/IMF (Netflix, Кинопоиск) |
| Рекламодатель / аналитик | QoE-метрики (воспринимаемое качество), retention (удержание аудитории), heatmap (тепловая карта активности) |

**Ключевые сценарии:** upload → transcode → publish; VOD playback с ABR (адаптивный битрейт); live streaming; аналитика просмотров и рекомендации; защита premium-контента (DRM — управление цифровыми правами).

**Масштаб (порядок величин):**

| Платформа | Каталог | Просмотры | Upload | CDN peak |
|-----------|---------|-----------|--------|----------|
| YouTube | 800M+ видео | 1B+ часов/день | 500 ч/мин | 100+ Tbps |
| Netflix | ~17K тайтлов | ~160M часов/день | Centralized | ~15% мирового трафика |
| Twitch | ~10M стримеров | ~30M зрителей | 7.5M стримеров/мес | ~3% мирового трафика |
| Кинопоиск | ~200К тайтлов | ~5M | Centralized | Сотни Gbps |

**Почему не «файл в Dropbox»:** единица контента — не один файл, а 10–20 вариантов × тысячи 2-секундных чанков; паттерн доступа 1:100K–100M; upload требует часов CPU; latency >2 сек = уход пользователя; download >> upload (100–1000×).

---

## 1. Компоненты


| # | Компонент | Тип | Ответственность | Stateful / Stateless |
|---|-----------|-----|-----------------|---------------------|
| 1 | API Gateway / Load Balancer | Балансировщик | TLS, маршрутизация, rate limiting | Stateless |
| 2 | Video Ingest | Сервис | Resumable upload (загрузка с докачкой, валидация, GOP-based chunking исходника (GOP — группа кадров) | Stateless |
| 3 | Transcode Pipeline | Worker pool | Параллельное кодирование в quality ladder (лестница качества: 1080p/720p/480p × H.264/VP9/AV1); per-title encoding (Netflix) | Stateless workers |
| 4 | Object Storage | Хранилище | Original + все варианты: `[resolution/codec/chunkNNN]` | Stateful |
| 5 | Event Bus (Kafka/SQS) | Очередь событий | `video.uploaded` → `video.transcoded` → `video.published` → `video.watched` | Stateful (log) |
| 6 | Video Serving | Сервис | Генерация manifest (`.m3u8`/`.mpd`), URL чанков, DRM packaging | Stateless |
| 7 | CDN / Edge | CDN | Кеширование и отдача чанков из PoP (точка присутствия) ближе к пользователю (Open Connect, Google Edge) | Stateful (cache) |
| 8 | Metadata Service | Сервис | Каталог, пользователи, права, рекомендации | Stateless |
| 9 | Metadata Store | БД | SQL/NoSQL: метаданные видео, профили, подписки | Stateful |

Event bus здесь "на критическом пути" — в отличие от облачного хранилища, где он вспомогательный. Без него upload не превращается в готовый к просмотру контент.

---

## 2. Потоки данных

### 2.1. Загрузка и транскодирование (VOD upload)

**Путь:** Creator → API Gateway → Video Ingest → Object Storage → Event Bus → Transcode Pipeline → Object Storage → Event Bus → Metadata Service.

1. Клиент инициирует resumable upload, шлёт чанки.
2. Ingest сохраняет original в Object Storage, публикует `video.uploaded`.
3. Transcode Pipeline разбивает видео на GOP-чанки (2–10 сек) и параллельно кодирует каждый в 10–20 вариантов. Фильм 2 ч ≈ 3600 чанков × 15 вариантов = 54 000 задач на кластер (Borg/Cosmos).
4. Результат: master manifest + десятки тысяч маленьких файлов в storage.
5. `video.transcoded` → Metadata Service помечает видео как ready.

**Sync/async:** upload — синхронный HTTP; transcode — полностью асинхронный через event bus.

**При сбое:** resumable upload переживает обрыв сети; failed encode job — retry на другом worker; при падении Kafka — backlog, видео «зависает» в processing.

---

### 2.2. Адаптивное воспроизведение (VOD playback + ABR)

**Путь:** Viewer → Client Player → CDN (manifest + chunks) → [DRM License Server].

1. Player запрашивает master manifest — список всех вариантов качества и URL чанков.
2. ABR-алгоритм (throughput-based, buffer-based, MPC у Netflix) выбирает качество следующего чанка по скорости канала и уровню буфера.
3. Player скачивает 2-секундные чанки с CDN Edge. Cache hit для VOD >95%.
4. При переходе Wi-Fi → 3G player переключается 1080p → 480p → 360p без остановки (буфер ~4 сек).

**Sync/async:** полностью синхронный pull-модель HTTP; аналитика (`buffer_health`, `position_sec`) — асинхронная отправка событий.

**При сбое:** CDN miss → origin pull (latency spike); persistent CDN failure → retry другой PoP + downgrade bitrate; DRM failure → ошибка пользователю, plaintext fallback невозможен.

---

### 2.3. Live-трансляция

**Путь:** Streamer (OBS) → Ingest Server (RTMP) → Real-time Transcoder → Origin (sliding window) → CDN → Viewers.

1. Стример пушит RTMP на ближайший ingest PoP (~100 по миру).
2. Transcoder кодирует каждый 2-сек чанк **быстрее real-time** (<1 сек budget) в 3 качества H.264.
3. Origin хранит последние N чанков; CDN fan-out к миллионам зрителей.
4. Cache hit для live = **0%** для первого чанка — контент появляется в реальном времени.

**При сбое:** потерянный кадр при live — навсегда (vs VOD, где можно перекодировать). Thundering herd при старте финала: 10M × 5 Mbps ≈ 50 Tbps.

---

### 2.4. Защита premium-контента (DRM)

**Путь:** Player → Video Serving (manifest без ключа) → DRM License Server → TEE на устройстве.

1. Manifest содержит `key_id`, но не ключ.
2. License Server проверяет подписку, geo, device attestation.
3. Ключ расшифровывается в hardware TEE (доверенная среда выполнения): Widevine L1 → 4K; L3 в Chrome → max 720p.
4. Forensic watermarking — уникальная метка на сессию для поиска источника утечки.

DRM не защищает от screen capture — только forensic watermarking + legal.

---

## 3. Проблемы и решения

_Какие проблемы решает каждый компонент._

## 4. Вопросы к авторам архитектуры

_Минимум 5 неочевидных вопросов._
