class CreateUserAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :user_audit_events do |t|
      t.references :user, foreign_key: { on_delete: :nullify }, null: true
      t.references :actor_user, foreign_key: { to_table: :users, on_delete: :nullify }, null: true
      t.string :action, null: false
      t.text :metadata
      t.string :ip_address
      t.string :user_agent
      t.datetime :created_at, null: false
    end

    add_index :user_audit_events, [ :user_id, :created_at ]
    add_index :user_audit_events, [ :actor_user_id, :created_at ]
    add_index :user_audit_events, :action
  end
end
