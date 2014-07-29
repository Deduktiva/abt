class InvoiceLineSerializer < ActiveModel::Serializer
  attributes :amount, :description, :quantity, :rate, :title, :type,
             :sales_tax_product_class_id, :sales_tax_indicator_code, :sales_tax_name, :sales_tax_rate
end
