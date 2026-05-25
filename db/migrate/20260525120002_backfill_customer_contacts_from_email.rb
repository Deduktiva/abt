class BackfillCustomerContactsFromEmail < ActiveRecord::Migration[8.1]
  def up
    # Use a lightweight inline model so this stays decoupled from app code
    # that might change shape later.
    customer = Class.new(ActiveRecord::Base) { self.table_name = "customers" }
    contact  = Class.new(ActiveRecord::Base) { self.table_name = "customer_contacts" }

    customer.where.not(email: [ nil, "" ]).find_each do |c|
      next if contact.where(customer_id: c.id).exists?

      name = c.name.presence || c.email.split("@", 2).first
      contact.create!(
        customer_id: c.id,
        name: name,
        email: c.email,
        receives_invoice_emails: true,
        receives_delivery_note_emails: true,
        created_at: Time.current,
        updated_at: Time.current
      )
    end
  end

  def down
    # No-op: dropping the synthetic contacts on rollback would discard data
    # the user may have edited since the backfill.
  end
end
