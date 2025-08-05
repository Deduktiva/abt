class RemoveTimeBudgetColumns < ActiveRecord::Migration[8.0]
  def change
    remove_column :customers, :time_budget, :integer
    remove_column :projects, :time_budget, :integer
  end
end
