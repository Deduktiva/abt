class CreateUserCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :user_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.text :external_id, null: false
      t.text :public_key, null: false
      t.string :nickname, null: false
      t.integer :sign_count, null: false, default: 0
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :user_credentials, :external_id, unique: true
  end
end
