# Himanshu Box Office

Minimal ticketing service with temporary seat holds and bookings.

Assumes the app is served at `http://localhost:8080` for local demos.

## GitHub

Repository link: (add once pushed) — e.g. `https://github.com/<org>/himanshu_box_office`

To push this codebase:
```
git init
git remote add origin git@github.com:<org>/himanshu_box_office.git
git add .
git commit -m "Initial commit"
git push -u origin main
```

## Architecture overview

```mermaid
flowchart LR
  Client[[Client / cURL]] -->|JSON| Ctrls
  subgraph Rails_App
    Ctrls[Controllers<br/>Events/Holds/Bookings]
    Models[Models<br/>Event/Hold/Booking]
    Job[HoldExpiryJob]
    Sched[In-process Scheduler<br/>(dev/test only)]
  end
  Ctrls --> Models
  Models --> DB[(MySQL 8)]
  Sched --> Job --> Models
  Idem[Idempotency:<br/>/book returns existing booking by hold_id<br/>Unique index on bookings.hold_id]
  Ctrls -. guards .-> Idem
```

### Key modules
- Controllers: `EventsController`, `HoldsController`, `BookingsController`
- Models: `Event`, `Hold`, `Booking`
- Expiry worker: `HoldExpiryJob`
- Scheduler (dev/test): `config/initializers/scheduler.rb` runs `HoldExpiryJob` every 30s

## Data model

- `events`
  - `name` (indexed), `total_seats`
- `holds`
  - `event_id` (FK), `qty`, `expires_at`, `status` (enum: active/expired/booked), `payment_token` (unique)
  - Indexes: `event_id`, `expires_at`, `status`, unique `payment_token`
- `bookings`
  - `event_id` (FK), `hold_id` (FK, unique), `qty`
  - Indexes: `event_id`, unique `hold_id`

Snapshot math (computed in `Event#snapshot`):
- `held`: sum of `holds.qty` where `status = active` and `expires_at > now`
- `booked`: sum of `bookings.qty`
- `available = max(total_seats - held - booked, 0)`

## Expiry/worker design

- TTL: holds default to 120 seconds (`HoldsController::HOLD_TTL_SECONDS`).
- A lightweight in-process scheduler (dev/test) invokes `HoldExpiryJob.perform_now` every 30 seconds.
- `HoldExpiryJob` marks holds as `expired` if `status = active` and `expires_at <= now`, unless already booked.
- Production: replace with a real background processor (Sidekiq/Resque) or cron.

## Concurrency & idempotency

- Concurrency safety
  - Creating a hold: wraps in a transaction and `SELECT ... FOR UPDATE` on the `events` row to avoid oversubscription when checking `snapshot.available`.
  - Booking: locks the `holds` row and the corresponding `events` row to serialize booking state transitions.

- Idempotency of `/book`
  - Request must include the `payment_token` that was issued with the hold.
  - If a booking for the `hold_id` already exists, the same `booking_id` is returned (200 OK).
  - Database-level unique index on `bookings.hold_id` guarantees one booking per hold; rescue returns existing booking.

## APIs

- POST `/events`
```
{ "event": { "name": "Concert", "total_seats": 100 } }
=> { "event_id": 1, "total_seats": 100, "created_at": "..." }
```

- GET `/events/:id`
```
=> { "total": 100, "available": 98, "held": 2, "booked": 0 }
```

- POST `/holds`
```
{ "hold": { "event_id": 1, "qty": 2 } }
=> { "hold_id": 5, "expires_at": "...", "payment_token": "uuid" }
```

- POST `/book`
```
{ "booking": { "hold_id": 5, "payment_token": "uuid" } }
=> { "booking_id": 7 }
```

## Demo (cURL, localhost:8080)

```bash
BASE=http://localhost:8080

# 1) Create event (capacity 5)
curl -sS -X POST "$BASE/events" -H 'Content-Type: application/json' \
  -d '{"event":{"name":"Demo Concert","total_seats":5}}' | tee event.json
EVENT_ID=$(ruby -rjson -e 'puts JSON.parse(STDIN.read)["event_id"]' < event.json)
echo "EVENT_ID=$EVENT_ID"

# 2) Two concurrent holds (qty=3) — expect one success, one failure
( curl -sS -X POST "$BASE/holds" -H 'Content-Type: application/json' \
    --data-raw "{\"hold\":{\"event_id\": $EVENT_ID, \"qty\": 3}}" | tee hold1.json ) &
( curl -sS -X POST "$BASE/holds" -H 'Content-Type: application/json' \
    --data-raw "{\"hold\":{\"event_id\": $EVENT_ID, \"qty\": 3}}" | tee hold2.json ) &
wait

# Identify the winning hold
SUCCESS_FILE=$(grep -l '"hold_id"' hold1.json hold2.json)
HOLD_ID=$(ruby -rjson -e 'puts JSON.parse(STDIN.read)["hold_id"]' < "$SUCCESS_FILE")
PAYMENT_TOKEN=$(ruby -rjson -e 'puts JSON.parse(STDIN.read)["payment_token"]' < "$SUCCESS_FILE")
echo "HOLD_ID=$HOLD_ID"; echo "PAYMENT_TOKEN=$PAYMENT_TOKEN"

# 3) Book the successful hold
curl -sS -X POST "$BASE/book" -H 'Content-Type: application/json' \
  --data-raw "{\"booking\":{\"hold_id\": $HOLD_ID, \"payment_token\": \"$PAYMENT_TOKEN\"}}" | tee booking1.json

# 4) Expiry demo — create a small extra hold, then force-expire it
curl -sS "$BASE/events/$EVENT_ID" | tee snapshot_before.json
curl -sS -X POST "$BASE/holds" -H 'Content-Type: application/json' \
  -d "{\"hold\":{\"event_id\": $EVENT_ID, \"qty\": 2}}" | tee expiring_hold.json
EXP_HOLD_ID=$(ruby -rjson -e 'puts JSON.parse(STDIN.read)["hold_id"]' < expiring_hold.json)
curl -sS "$BASE/events/$EVENT_ID" | tee snapshot_pre_expiry.json
bin/rails runner "h=Hold.find($EXP_HOLD_ID); h.update!(expires_at: 2.minutes.ago)"
bin/rails runner 'HoldExpiryJob.perform_now'
curl -sS "$BASE/events/$EVENT_ID" | tee snapshot_post_expiry.json

# 5) Idempotent retry of /book
curl -sS -X POST "$BASE/book" -H 'Content-Type: application/json' \
  --data-raw "{\"booking\":{\"hold_id\": $HOLD_ID, \"payment_token\": \"$PAYMENT_TOKEN\"}}" | tee booking_retry.json
```

## Run locally

1. Ensure MySQL 8 is running (update `config/database.yml` if needed).
2. Setup:
```
bundle install
bin/rails db:create db:migrate
bin/rails server -p 8080
```

## Known trade-offs

- In-process scheduler (dev/test) is not suitable for production; use Sidekiq/cron for reliability and observability.
- Expiry cadence is 30s, so release of expired holds is eventual within that window.
- Snapshot-based availability sums can be heavier on large datasets; consider counters/cache if needed.
- Row locking on `events` and `holds` serializes some hot paths; scale via sharding per event or queueing.
- `payment_token` ensures a hold is bound to a request flow, but idempotency is enforced at booking time by `hold_id` uniqueness, not the token itself.
