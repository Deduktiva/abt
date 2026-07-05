class CreateOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :offers do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.references :customer_contact, foreign_key: true
      t.string :state, null: false, default: "draft"
      t.string :document_number
      t.date :date
      t.datetime :sent_at
      t.datetime :accepted_at
      t.datetime :rejected_at
      t.date :expires_at
      t.datetime :reported_expired_at
      t.bigint :accepted_version_id
      t.text :order_number
      t.date :ordered_on
      t.references :order_attachment, foreign_key: { to_table: :attachments }
      t.text :internal_reference
      t.datetime :email_sent_at
      t.timestamps
    end
    add_index :offers, :document_number, unique: true
    add_index :offers, :state
  end
end
