class MakeDocumentEmailAutoBccOptional < ActiveRecord::Migration[8.1]
  def up
    # Blank means "no BCC", matching document_email_reply_to. Existing rows keep
    # whatever address they hold; only new installs start without a BCC.
    change_column_null :businesses, :document_email_auto_bcc, true
    change_column_default :businesses, :document_email_auto_bcc, from: "bcc@example.com", to: nil

    # "" was the only way to express "no BCC" while the column was NOT NULL.
    execute "UPDATE businesses SET document_email_auto_bcc = NULL WHERE trim(document_email_auto_bcc) = ''"
  end

  def down
    execute "UPDATE businesses SET document_email_auto_bcc = '' WHERE document_email_auto_bcc IS NULL"
    change_column_default :businesses, :document_email_auto_bcc, from: nil, to: "bcc@example.com"
    change_column_null :businesses, :document_email_auto_bcc, false
  end
end
