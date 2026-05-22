class CreateUserSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_seen_at, null: false
      t.datetime :terminated_at
      t.references :terminated_by_user, foreign_key: { to_table: :users }, null: true
      t.string :termination_reason

      t.timestamps
    end

    add_index :user_sessions, :token_digest, unique: true
    add_index :user_sessions, [:user_id, :terminated_at]
  end
end
