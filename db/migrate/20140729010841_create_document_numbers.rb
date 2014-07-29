class CreateDocumentNumbers < ActiveRecord::Migration
  def change
    create_table :document_numbers do |t|
      t.string :code
      t.string :format
      t.integer :sequence
      t.string :last_number
      t.date :last_date

      t.timestamps
    end
  end
end
