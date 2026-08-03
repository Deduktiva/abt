class RequireNonBlankBusinessEmails < ActiveRecord::Migration[8.1]
  def change
    # NOT NULL alone still admits "", and mail with a blank sender or recipient
    # is a silent no-op the report jobs then record as delivered.
    add_check_constraint :businesses, "trim(reporting_email) <> ''",
                         name: "businesses_reporting_email_not_blank"
    add_check_constraint :businesses, "trim(document_email_from) <> ''",
                         name: "businesses_document_email_from_not_blank"
  end
end
