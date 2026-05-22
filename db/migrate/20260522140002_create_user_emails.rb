class CreateUserEmails < ActiveRecord::Migration[8.1]
  def change
    create_table :user_emails do |t|
      t.references :user, null: false, foreign_key: true
      t.string :address, null: false
      t.datetime :confirmed_at
      t.string :confirmation_token_digest
      t.datetime :confirmation_expires_at

      t.timestamps
    end

    add_index :user_emails, :address, unique: true
    add_index :user_emails, :confirmation_token_digest, unique: true, where: 'confirmation_token_digest IS NOT NULL'
  end
end
