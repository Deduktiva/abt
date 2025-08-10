class CreateDeliveryNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_notes do |t|
      t.string :document_number
      t.boolean :published
      t.references :customer, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.references :attachment, null: true, foreign_key: true
      t.date :date
      t.string :cust_reference
      t.string :cust_order
      t.text :prelude
      t.datetime :email_sent_at
      t.references :invoice, null: true, foreign_key: true

      t.timestamps
    end
    add_index :delivery_notes, :document_number, unique: true
    add_index :delivery_notes, :published
    add_index :delivery_notes, :date
  end
end
