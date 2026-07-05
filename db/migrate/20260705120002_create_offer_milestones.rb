class CreateOfferMilestones < ActiveRecord::Migration[8.1]
  def change
    create_table :offer_milestones do |t|
      t.references :offer_version, null: false, foreign_key: true
      t.integer :position
      t.string :title, null: false
      t.text :description
      t.string :trigger, null: false, default: "on_acceptance"
      t.date :trigger_date
      t.decimal :amount, null: false
      t.boolean :skip_delivery_note, null: false, default: false
      t.references :invoice, foreign_key: true, index: false
      t.references :delivery_note, foreign_key: true, index: false
      t.timestamps
    end
    add_index :offer_milestones, :invoice_id, unique: true, where: "invoice_id IS NOT NULL"
    add_index :offer_milestones, :delivery_note_id, unique: true, where: "delivery_note_id IS NOT NULL"
  end
end
