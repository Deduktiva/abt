class RequireReportingEmailOnIssuerCompanies < ActiveRecord::Migration[8.1]
  def up
    # All existing rows were backfilled by the previous migration; this
    # locks in the invariant that reports always have a recipient.
    execute <<~SQL
      UPDATE issuer_companies
      SET reporting_email = document_email_auto_bcc
      WHERE reporting_email IS NULL OR reporting_email = ''
    SQL

    change_column_null :issuer_companies, :reporting_email, false
    change_column_default :issuer_companies, :reporting_email, from: nil, to: "bcc@example.com"
  end

  def down
    change_column_default :issuer_companies, :reporting_email, from: "bcc@example.com", to: nil
    change_column_null :issuer_companies, :reporting_email, true
  end
end
