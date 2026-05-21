class CreateUserInvites < ActiveRecord::Migration[8.0]
  def change
    create_table :user_invites do |t|
      t.string :token, null: false
      t.references :created_by_user, null: true, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.references :consumed_by_user, null: true, foreign_key: { to_table: :users }
      t.string :note

      t.timestamps
    end

    add_index :user_invites, :token, unique: true
    add_index :user_invites, :expires_at
  end
end
