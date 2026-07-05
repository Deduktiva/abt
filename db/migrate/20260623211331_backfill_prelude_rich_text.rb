class BackfillPreludeRichText < ActiveRecord::Migration[8.1]
  # Lightweight stand-ins so this migration is independent of model code.
  class MigrationInvoice < ActiveRecord::Base
    self.table_name = "invoices"
  end

  class MigrationDeliveryNote < ActiveRecord::Base
    self.table_name = "delivery_notes"
  end

  def up
    [ [ "Invoice", MigrationInvoice ], [ "DeliveryNote", MigrationDeliveryNote ] ].each do |type, klass|
      klass.where.not(prelude: [ nil, "" ]).find_each do |record|
        create_prelude_rich_text(type, record.id, record.prelude)
      end
    end
  end

  def create_prelude_rich_text(record_type, record_id, prelude_text)
    ActionText::RichText.create!(
      name: "prelude",
      record_type: record_type,
      record_id: record_id,
      body: ActionController::Base.helpers.simple_format(prelude_text)
    )
  end

  def down
    ActionText::RichText.where(name: "prelude", record_type: %w[Invoice DeliveryNote]).find_each do |rich_text|
      klass = rich_text.record_type == "Invoice" ? MigrationInvoice : MigrationDeliveryNote
      klass.where(id: rich_text.record_id).update_all(prelude: rich_text.body.to_plain_text)
      rich_text.destroy!
    end
  end
end
