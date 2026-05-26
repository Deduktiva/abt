class RequireMatchcodeNotNull < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE customers SET matchcode = 'CUST-' || id WHERE matchcode IS NULL"
    execute "UPDATE projects  SET matchcode = 'PROJ-' || id WHERE matchcode IS NULL"

    change_column_null :customers, :matchcode, false
    change_column_null :projects, :matchcode, false
  end

  def down
    change_column_null :customers, :matchcode, true
    change_column_null :projects, :matchcode, true
  end
end
