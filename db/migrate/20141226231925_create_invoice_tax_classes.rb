class CreateInvoiceTaxClasses < ActiveRecord::Migration[6.0]
  class Invoice < ActiveRecord::Base
    serialize :tax_classes, coder: YAML
    has_many :invoice_tax_classes
  end
  class InvoiceTaxClass < ActiveRecord::Base; end

  def change
    create_table :invoice_tax_classes do |t|
      t.integer :invoice_id
      t.integer :sales_tax_product_class_id
      t.string :name
      t.string :indicator_code
      t.decimal :rate
      t.decimal :net
      t.decimal :value
      t.decimal :total

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        Invoice.all.each do |invoice|
          next if !invoice.published?
          old_tax_classes = invoice.tax_classes
          old_tax_classes.each do |sales_tax_product_class_id, old_tax_class|
            old_tax_class.symbolize_keys!
            tax_class = InvoiceTaxClass.new
            tax_class.sales_tax_product_class_id = sales_tax_product_class_id
            tax_class.name = old_tax_class[:name]
            tax_class.indicator_code = old_tax_class[:indicator_code]
            tax_class.rate = old_tax_class[:rate]
            tax_class.net = old_tax_class[:net]
            tax_class.value = old_tax_class[:value]
            tax_class.total = old_tax_class[:total]
            invoice.invoice_tax_classes << tax_class
          end
          invoice.save!
        end
      end
      dir.down do
        Invoice.all.each do |invoice|
          next if !invoice.published?
          old_tax_classes = invoice.invoice_tax_classes
          tax_classes = {}
          old_tax_classes.each do |old_tax_class|
            tax_class = {}
            tax_class[:name] = old_tax_class.name
            tax_class[:indicator_code] = old_tax_class.indicator_code
            tax_class[:rate] = old_tax_class.rate.to_f
            tax_class[:net] = old_tax_class.net.to_f
            tax_class[:value] = old_tax_class.value.to_f
            tax_class[:total] = old_tax_class.total.to_f
            tax_classes[old_tax_class.sales_tax_product_class_id] = tax_class
          end
          invoice.tax_classes = tax_classes
          invoice.save!
        end
      end
    end

    remove_column :invoices, :tax_classes, :text
  end
end
