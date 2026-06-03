class AddAcceptanceUploadTokenToDeliveryNotes < ActiveRecord::Migration[8.1]
  def up
    add_column :delivery_notes, :acceptance_upload_token_digest, :string
    add_column :delivery_notes, :acceptance_upload_token_minted_at, :datetime
    add_column :delivery_notes, :acceptance_upload_token_expires_at, :datetime
    add_index :delivery_notes, :acceptance_upload_token_digest, unique: true
  end

  def down
    remove_index :delivery_notes, :acceptance_upload_token_digest
    remove_column :delivery_notes, :acceptance_upload_token_expires_at
    remove_column :delivery_notes, :acceptance_upload_token_minted_at
    remove_column :delivery_notes, :acceptance_upload_token_digest
  end
end
