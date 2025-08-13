class AddDeliveryTimeframeToDeliveryNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :delivery_notes, :delivery_start_date, :date
    add_column :delivery_notes, :delivery_end_date, :date
  end
end
