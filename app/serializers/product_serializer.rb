class ProductSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :rate, :sales_tax_product_class_id
end
