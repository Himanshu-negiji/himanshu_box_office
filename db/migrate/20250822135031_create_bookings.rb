class CreateBookings < ActiveRecord::Migration[7.2]
  def change
    create_table :bookings do |t|
      t.references :event, null: false, foreign_key: true
      t.references :hold, null: false, foreign_key: true, index: { unique: true }
      t.integer :qty, null: false

      t.timestamps
    end
  end
end
