class CreateCustomers < ActiveRecord::Migration
  def change
    create_table :customers do |t|
      t.string :matchcode
      t.text :name
      t.text :address
      t.integer :time_budget
      t.text :notes

      t.timestamps
    end
  end
end
