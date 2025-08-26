# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_08_22_135031) do
  create_table "bookings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "hold_id", null: false
    t.integer "qty", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_bookings_on_event_id"
    t.index ["hold_id"], name: "index_bookings_on_hold_id", unique: true
  end

  create_table "events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.integer "total_seats", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_events_on_name"
  end

  create_table "holds", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.integer "qty", null: false
    t.datetime "expires_at", null: false
    t.string "status", default: "active", null: false
    t.string "payment_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_holds_on_event_id"
    t.index ["expires_at"], name: "index_holds_on_expires_at"
    t.index ["payment_token"], name: "index_holds_on_payment_token", unique: true
    t.index ["status"], name: "index_holds_on_status"
  end

  add_foreign_key "bookings", "events"
  add_foreign_key "bookings", "holds"
  add_foreign_key "holds", "events"
end
