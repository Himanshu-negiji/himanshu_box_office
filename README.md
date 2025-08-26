# Himanshu Box Office

Minimal ticketing service with temporary holds and bookings.

## Storage
MySQL 8 via `mysql2` adapter. In-memory expiry scheduler runs in-process for dev/test.

## Run locally

1. Ensure MySQL 8 is running and you have a `root` user with no password or update `config/database.yml` accordingly.
2. Setup:
```
bundle install
bin/rails db:create db:migrate
bin/rails server
```

## APIs

- POST `/events`
```
{
  "event": { "name": "Concert", "total_seats": 100 }
}
=> { "event_id": 1, "total_seats": 100, "created_at": "..." }
```

- GET `/events/:id`
```
=> { "total": 100, "available": 98, "held": 2, "booked": 0 }
```

- POST `/holds`
```
{
  "hold": { "event_id": 1, "qty": 2 }
}
=> { "hold_id": 5, "expires_at": "...", "payment_token": "uuid" }
```

- POST `/book`
```
{
  "booking": { "hold_id": 5, "payment_token": "uuid" }
}
=> { "booking_id": 7 }
```

## cURL
```
curl -X POST http://localhost:3000/events \
  -H 'Content-Type: application/json' \
  -d '{"event": {"name": "Concert", "total_seats": 50}}'

curl http://localhost:3000/events/1

curl -X POST http://localhost:3000/holds \
  -H 'Content-Type: application/json' \
  -d '{"hold": {"event_id": 1, "qty": 2}}'

curl -X POST http://localhost:3000/book \
  -H 'Content-Type: application/json' \
  -d '{"booking": {"hold_id": 1, "payment_token": "<token>"}}'
```

## Notes
- Holds expire after 2 minutes. Scheduler marks expired every 30s.
- Concurrency safety: row-level locks on `events` and `holds` prevent oversubscription.
- Booking is idempotent by unique index on `bookings.hold_id` and pre-check.
# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
