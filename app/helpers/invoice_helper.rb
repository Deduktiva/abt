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

end