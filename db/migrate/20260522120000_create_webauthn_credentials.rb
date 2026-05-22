class CreateWebauthnCredentials < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :webauthn_id, :string
    add_index  :users, :webauthn_id, unique: true

    create_table :webauthn_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.text :external_id, null: false
      t.text :public_key, null: false
      t.integer :sign_count, null: false, default: 0
      t.string :nickname
      t.json :transports
      t.string :aaguid
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :webauthn_credentials, :external_id, unique: true
  end
end
