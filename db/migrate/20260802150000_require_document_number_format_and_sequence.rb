class RequireDocumentNumberFormatAndSequence < ActiveRecord::Migration[8.1]
  # This will crash if any row is missing a format or a sequence.
  def up
    change_column_null :document_numbers, :format, false
    change_column_null :document_numbers, :sequence, false
  end

  def down
    change_column_null :document_numbers, :format, true
    change_column_null :document_numbers, :sequence, true
  end
end
