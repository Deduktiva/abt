class CreateUserInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :user_invites do |t|
      t.string :token_digest, null: false
      t.references :created_by_user, foreign_key: { to_table: :users }, null: true
      t.string :purpose, null: false
      t.references :target_user, foreign_key: { to_table: :users }, null: true
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.references :used_by_user, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :user_invites, :token_digest, unique: true
    add_index :user_invites, :expires_at
  end
end
