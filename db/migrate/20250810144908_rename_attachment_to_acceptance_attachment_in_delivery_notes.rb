class RenameAttachmentToAcceptanceAttachmentInDeliveryNotes < ActiveRecord::Migration[8.0]
  def change
    rename_column :delivery_notes, :attachment_id, :acceptance_attachment_id
  end
end
