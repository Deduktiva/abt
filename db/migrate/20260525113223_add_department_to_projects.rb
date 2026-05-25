class AddDepartmentToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :department, :string
  end
end
