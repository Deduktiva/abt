class AddIndexToProjectMatchcode < ActiveRecord::Migration[8.0]
  def change
    add_index :projects, :matchcode
  end
end
