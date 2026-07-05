class AddOfferDocumentNumber < ActiveRecord::Migration[8.1]
  class MigrationDocumentNumber < ActiveRecord::Base
    self.table_name = "document_numbers"
  end

  def up
    return if MigrationDocumentNumber.exists?(code: "offer")
    MigrationDocumentNumber.create!(code: "offer", format: "%{date}-%<number>02d", sequence: 0)
  end

  def down
    MigrationDocumentNumber.where(code: "offer").delete_all
  end
end
