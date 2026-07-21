# API 1 — Search (GraphQL)

**Зачем GraphQL:** web и mobile запрашивают разный набор полей карточки
(карта vs список) без over/under-fetching. Gateway резолвит в gRPC `Search.Query`.

## Endpoint

`POST /graphql` (через Gateway)

## Query

```graphql
query SearchProperties($input: SearchInput!) {
  searchProperties(input: $input) {
    total
    items {
      propertyId
      name
      stars
      geo { lat lon }
      minPrice { amount currency }
      availableRoomTypes
      thumbnailUrl
    }
  }
}
```

### Variables (пример)

```json
{
  "input": {
    "geo": { "lat": 55.75, "lon": 37.62, "radiusKm": 5 },
    "checkIn": "2026-08-10",
    "checkOut": "2026-08-12",
    "guests": 2,
    "filters": { "starsMin": 3, "amenities": ["WIFI", "PARKING"] },
    "sort": "PRICE_ASC",
    "page": { "limit": 20, "offset": 0 }
  }
}
```

## Ответ (фрагмент)

```json
{
  "data": {
    "searchProperties": {
      "total": 128,
      "items": [
        {
          "propertyId": "prop_01HZX...",
          "name": "Loft on Arbat",
          "stars": 4,
          "geo": { "lat": 55.75, "lon": 37.59 },
          "minPrice": { "amount": "9200.00", "currency": "RUB" },
          "availableRoomTypes": 2,
          "thumbnailUrl": "https://cdn.example/..."
        }
      ]
    }
  }
}
```

## Семантика

- **Public API** (JWT не обязателен); rate-limit на Gateway / IP.
- Результат **eventually consistent** (CQRS read-model).
- Наличие в выдаче **не резервирует** слот — резерв только через create booking → Hold.
- Ошибки: `BAD_USER_INPUT` (даты в прошлом, checkOut ≤ checkIn), `RATE_LIMITED`.

## Internal

`search.v1.SearchService/Query` — gRPC, Protobuf.
