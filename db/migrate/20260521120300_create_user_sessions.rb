class CreateUserSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :user_agent
      t.string :ip
      t.datetime :last_seen_at, null: false
      t.datetime :terminated_at
      t.string :terminated_reason

      t.timestamps
    end

    add_index :user_sessions, :token_digest, unique: true
    add_index :user_sessions, [:user_id, :terminated_at]
  end
end
