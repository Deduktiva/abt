class TightenInvoiceDeliveryNoteNullConstraints < ActiveRecord::Migration[8.1]
  def up
    # invoices
    change_column_default :invoices, :sum_net,   from: nil, to: 0
    change_column_default :invoices, :sum_total, from: nil, to: 0
    change_column_default :invoices, :published, from: nil, to: false
    change_column_null :invoices, :sum_net,    false, 0
    change_column_null :invoices, :sum_total,  false, 0
    change_column_null :invoices, :published,  false, false
    change_column_null :invoices, :customer_id, false # validated; no backfill (fail loud if any NULL)
    change_column_null :invoices, :project_id,  false

    # delivery_notes
    change_column_default :delivery_notes, :published, from: nil, to: false
    change_column_null :delivery_notes, :published, false, false
    change_column_null :delivery_notes, :delivery_start_date, false
  end

  def down
    change_column_null :delivery_notes, :delivery_start_date, true
    change_column_null :delivery_notes, :published, true
    change_column_default :delivery_notes, :published, from: false, to: nil

    change_column_null :invoices, :project_id,  true
    change_column_null :invoices, :customer_id, true
    change_column_null :invoices, :published,  true
    change_column_null :invoices, :sum_total,  true
    change_column_null :invoices, :sum_net,    true
    change_column_default :invoices, :published, from: false, to: nil
    change_column_default :invoices, :sum_total, from: 0, to: nil
    change_column_default :invoices, :sum_net,   from: 0, to: nil
  end
end
