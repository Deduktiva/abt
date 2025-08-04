class AddActiveToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :active, :boolean, default: true, null: false
    # Set all existing projects to active
    execute "UPDATE projects SET active = true"
  end
end
