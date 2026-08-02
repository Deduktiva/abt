class UniqueIndexDocumentNumbers < ActiveRecord::Migration[8.1]
  # This will crash if the uniqueness is not satisfied.
  def up
    change_column_null :document_numbers, :code, false
    add_index :document_numbers, :code, unique: true
  end

  def down
    remove_index :document_numbers, :code
    change_column_null :document_numbers, :code, true
  end
end
