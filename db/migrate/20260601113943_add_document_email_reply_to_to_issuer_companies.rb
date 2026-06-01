class AddDocumentEmailReplyToToIssuerCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :issuer_companies, :document_email_reply_to, :string
  end
end
