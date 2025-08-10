class AddLanguageToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_reference :customers, :language, null: true, foreign_key: true

    # Set default language (English) for existing customers
    reversible do |dir|
      dir.up do
        # Ensure English language exists
        english = Language.find_or_create_by(iso_code: 'en') do |lang|
          lang.title = 'English'
        end

        # Update all existing customers to have English as default
        Customer.update_all(language_id: english.id)

        # Now make the field required
        change_column_null :customers, :language_id, false
      end

      dir.down do
        # Remove the not null constraint when rolling back
        change_column_null :customers, :language_id, true
      end
    end
  end
end
