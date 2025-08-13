class CreateDeliveryNoteLines < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_note_lines do |t|
      t.references :delivery_note, null: false, foreign_key: true
      t.integer :position
      t.text :type
      t.text :title
      t.text :description
      t.float :quantity

      t.timestamps
    end
    add_index :delivery_note_lines, :position
  end
end
