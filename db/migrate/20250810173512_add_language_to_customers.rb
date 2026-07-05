class AddLanguageToCustomers < ActiveRecord::Migration[8.0]
  # Scoped to this migration instead of using the live Customer/Language
  # models: those models gain columns and validations over time (e.g.
  # Customer's invoice_email_auto_contact_mode enum, added months later),
  # which breaks this migration when it replays against an older schema.
  class MigrationLanguage < ApplicationRecord
    self.table_name = "languages"
  end

  class MigrationCustomer < ApplicationRecord
    self.table_name = "customers"
  end

  def change
    add_reference :customers, :language, null: true, foreign_key: true

    # Set default language (English) for existing customers
    reversible do |dir|
      dir.up do
        # Ensure English and German languages exist
        english = MigrationLanguage.find_or_create_by(iso_code: 'en') do |lang|
          lang.title = 'English'
        end

        MigrationLanguage.find_or_create_by(iso_code: 'de') do |lang|
          lang.title = 'German'
        end

        # Update all existing customers to have English as default
        MigrationCustomer.update_all(language_id: english.id)

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
