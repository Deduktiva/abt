class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :full_name, null: false
      t.string :webauthn_id, null: false
      t.datetime :blocked_at
      t.string :blocked_reason
      t.references :blocked_by_user, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :blocked_at
  end
end
