class AddUniqueMatchcodeIndexes < ActiveRecord::Migration[8.0]
  def change
    remove_index :projects, :matchcode, name: "index_projects_on_matchcode"
    add_index :customers, "LOWER(matchcode)", unique: true, name: "index_customers_on_lower_matchcode"
    add_index :projects, "LOWER(matchcode)", unique: true, name: "index_projects_on_lower_matchcode"
  end
end
