class AddDocumentEmailFromToIssuerCompany < ActiveRecord::Migration[7.1]
  def change
    add_column :issuer_companies, :document_email_from, :string, default: 'from@example.com', null: false
    add_column :issuer_companies, :document_email_auto_bcc, :string, default: 'bcc@example.com', null: false
  end
end
