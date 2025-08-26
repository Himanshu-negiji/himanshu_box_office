class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events do |t|
      t.string :name, null: false
      t.integer :total_seats, null: false

      t.timestamps
    end

    add_index :events, :name
  end
end
