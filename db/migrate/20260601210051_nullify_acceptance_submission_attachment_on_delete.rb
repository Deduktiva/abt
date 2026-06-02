class NullifyAcceptanceSubmissionAttachmentOnDelete < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :acceptance_submissions, :attachments
    add_foreign_key :acceptance_submissions, :attachments, on_delete: :nullify
  end

  def down
    remove_foreign_key :acceptance_submissions, :attachments
    add_foreign_key :acceptance_submissions, :attachments
  end
end
