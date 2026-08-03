class CaseInsensitiveGroupAndTeamNameIndexes < ActiveRecord::Migration[8.1]
  # Group and Team validate name uniqueness with case_sensitive: false, but the
  # indexes were byte-exact, so the DB never backed the validation. Swap them
  # for LOWER(name) indexes, matching the matchcode indexes on customers/projects.
  #
  # Strip first: Group/Team now normalize name with .strip, and an unstripped
  # existing row would no longer be findable by its own name.
  #
  # This will crash if the resulting uniqueness is not satisfied.
  def up
    execute "UPDATE groups SET name = TRIM(name) WHERE name <> TRIM(name)"
    execute "UPDATE teams SET name = TRIM(name) WHERE name <> TRIM(name)"

    remove_index :groups, :name, name: "index_groups_on_name"
    remove_index :teams, :name, name: "index_teams_on_name"
    add_index :groups, "LOWER(name)", unique: true, name: "index_groups_on_lower_name"
    add_index :teams, "LOWER(name)", unique: true, name: "index_teams_on_lower_name"
  end

  def down
    remove_index :groups, name: "index_groups_on_lower_name"
    remove_index :teams, name: "index_teams_on_lower_name"
    add_index :groups, :name, unique: true, name: "index_groups_on_name"
    add_index :teams, :name, unique: true, name: "index_teams_on_name"
  end
end
