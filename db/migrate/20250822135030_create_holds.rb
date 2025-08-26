class CreateHolds < ActiveRecord::Migration[7.2]
  def change
    create_table :holds do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :qty, null: false
      t.datetime :expires_at, null: false
      t.string :status, null: false, default: "active"
      t.string :payment_token, null: false

      t.timestamps
    end

    add_index :holds, :expires_at
    add_index :holds, :payment_token, unique: true
    add_index :holds, :status
  end
end
