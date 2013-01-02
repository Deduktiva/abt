class CreateProjects < ActiveRecord::Migration
  def change
    create_table :projects do |t|
      t.string :matchcode
      t.text :description
      t.integer :time_budget
      t.integer :bill_to_customer_id

      t.timestamps
    end
  end
end
