class CreateGroupsAndTeams < ActiveRecord::Migration[8.1]
  ADMIN_PERMISSIONS = %w[
    customers.view customers.edit
    projects.view projects.edit
    invoices.view invoices.edit
    delivery_notes.view delivery_notes.edit
    products.view products.edit
    sales_tax.view sales_tax.edit
    issuer_company.view issuer_company.edit
    users.view users.block users.reset_passkeys users.auto_confirm_email
    user_invites.manage
    groups.manage
    teams.manage
    jobs_status.view
  ].freeze

  def up
    create_table :groups do |t|
      t.string :name, null: false
      t.string :description
      t.boolean :builtin, default: false, null: false
      t.boolean :bypass_team_scoping, default: false, null: false
      t.timestamps
    end
    add_index :groups, :name, unique: true

    create_table :group_permissions do |t|
      t.references :group, null: false, foreign_key: true
      t.string :permission, null: false
      t.timestamps
    end
    add_index :group_permissions, [ :group_id, :permission ], unique: true

    create_table :group_memberships do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :group_memberships, [ :group_id, :user_id ], unique: true

    create_table :teams do |t|
      t.string :name, null: false
      t.string :description
      t.boolean :builtin, default: false, null: false
      # Exactly one team carries `default: true`. New users auto-join it via
      # User#join_default_team. Independent of `builtin` so the default team
      # can be renamed without breaking the lookup. The partial unique index
      # enforces "at most one default" at the DB level.
      t.boolean :default, default: false, null: false
      t.timestamps
    end
    add_index :teams, :name, unique: true
    add_index :teams, :default, unique: true, where: '"default"', name: "index_teams_unique_default"

    create_table :team_memberships do |t|
      t.references :team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :team_memberships, [ :team_id, :user_id ], unique: true

    # team_id columns on existing tables (nullable for backfill, NOT NULL added at end)
    add_reference :customers, :team, foreign_key: true, null: true
    add_reference :projects, :team, foreign_key: true, null: true

    # Seed built-in Admin group with all permissions and bypass scoping.
    # The literal name 'Admin' is intentional (migrations should be
    # self-contained and not depend on app constants that may rename).
    # Group::ADMIN_NAME mirrors it in the application layer.
    now = Time.current
    admin_group_id = execute_insert(
      'groups',
      name: 'Admin',
      description: 'Built-in administrator group with all permissions',
      builtin: true,
      bypass_team_scoping: true,
      created_at: now,
      updated_at: now
    )

    ADMIN_PERMISSIONS.each do |perm|
      execute_insert(
        'group_permissions',
        group_id: admin_group_id,
        permission: perm,
        created_at: now,
        updated_at: now
      )
    end

    # Seed built-in Default team and backfill memberships. Literal mirrored
    # by Team::DEFAULT_NAME in the application layer. `default: true` marks
    # this row as the new-user join target (see Team.default).
    default_team_id = execute_insert(
      'teams',
      name: 'Default',
      description: 'Built-in default team. All pre-existing users, customers and projects belong here.',
      builtin: true,
      default: true,
      created_at: now,
      updated_at: now
    )

    User.find_each do |user|
      execute_insert(
        'team_memberships',
        team_id: default_team_id,
        user_id: user.id,
        created_at: now,
        updated_at: now
      )
    end

    execute "UPDATE customers SET team_id = #{default_team_id} WHERE team_id IS NULL"
    execute "UPDATE projects  SET team_id = #{default_team_id} WHERE team_id IS NULL"

    change_column_null :customers, :team_id, false
    change_column_null :projects,  :team_id, false
  end

  def down
    remove_reference :projects,  :team, foreign_key: true
    remove_reference :customers, :team, foreign_key: true
    drop_table :team_memberships
    drop_table :teams
    drop_table :group_memberships
    drop_table :group_permissions
    drop_table :groups
  end

  private

  def execute_insert(table, attrs)
    conn = ActiveRecord::Base.connection
    cols = attrs.keys.map { |k| conn.quote_column_name(k) }.join(', ')
    vals = attrs.values.map { |v| conn.quote(v) }.join(', ')
    conn.insert(
      "INSERT INTO #{conn.quote_table_name(table)} (#{cols}) VALUES (#{vals})",
      "CreateGroupsAndTeams seed: #{table}"
    )
  end
end
