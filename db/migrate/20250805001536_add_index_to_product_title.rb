class AddIndexToProductTitle < ActiveRecord::Migration[8.0]
  def change
    add_index :products, :title
  end
end
