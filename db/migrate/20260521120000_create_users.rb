class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :full_name, null: false
      t.datetime :blocked_at
      t.string :blocked_reason
      t.references :blocked_by_user, null: true, foreign_key: { to_table: :users }
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :blocked_at
  end
end
