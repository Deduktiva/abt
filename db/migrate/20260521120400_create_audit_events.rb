class CreateAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_events do |t|
      t.references :subject_user, null: true, foreign_key: { to_table: :users }
      t.references :actor_user, null: true, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.json :metadata, null: false, default: {}
      t.string :ip
      t.string :user_agent

      t.datetime :created_at, null: false
    end

    add_index :audit_events, [:subject_user_id, :created_at]
    add_index :audit_events, [:event_type, :created_at]
    add_index :audit_events, :created_at
  end
end
