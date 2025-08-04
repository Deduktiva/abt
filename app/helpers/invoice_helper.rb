require 'jbuilder'

module InvoiceHelper

  def json_lines(lines, options = {})
    res = Jbuilder.new do |json|
      json.array! lines do |line|
        json.extract! line, :title, :description, :type, :rate, :quantity, :sales_tax_product_class_id
      end
    end
    res.target!
  end

  def json_products
    res = Jbuilder.new do |json|
      json.array! Product.all do |product|
        json.extract! product, :id, :title, :description, :rate, :sales_tax_product_class_id
      end
    end
    res.target!
  end

  def json_sales_tax_classes
    res = Jbuilder.new do |json|
      json.array! SalesTaxProductClass.all do |tax_class|
        json.extract! tax_class, :id, :name
      end
    end
    res.target!
  end

end
