# 6. Надёжность

> Часть [решения ДЗ 6](README.md). Схемы — в [`diagrams/`](diagrams/).

## 1. RTO / RPO по сервисам

_Тир по цене простоя/потери данных, раздельно локальный отказ и региональный (DR)._

## 2. Репликация критичных БД

_Data plane / control plane / routing plane; схема:
[`diagrams/replication-ha.puml`](diagrams/replication-ha.puml)._

## 3. Паттерны отказоустойчивости

_Timeout / retry / circuit breaker / bulkhead — где именно в системе и что предотвращают._

## 4. План DR

_Стратегия по тирам (Active-Active / Warm Standby / Pilot Light / Backup & Restore), порядок
восстановления; схема: [`diagrams/dr-failover.puml`](diagrams/dr-failover.puml)._

> **Черновые заметки (убрать перед сдачей):** формат — по образцу
> [ДЗ 5 §1–4](../../hw_05/solution/README.md#1-rto--rpo-по-сервисам).
