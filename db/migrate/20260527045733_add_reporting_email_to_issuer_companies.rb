class AddReportingEmailToIssuerCompanies < ActiveRecord::Migration[8.1]
  def up
    add_column :issuer_companies, :reporting_email, :string

    # Backfill so OverdueInvoicesReportJob keeps delivering to the address that
    # has been receiving overdue reports until now (it previously reused
    # document_email_auto_bcc, which is also the BCC for customer-facing mail).
    execute <<~SQL
      UPDATE issuer_companies
      SET reporting_email = document_email_auto_bcc
      WHERE reporting_email IS NULL
    SQL
  end

  def down
    remove_column :issuer_companies, :reporting_email
  end
end
