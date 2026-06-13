class GrantReviewAcceptanceToAdminGroup < ActiveRecord::Migration[8.1]
  # delivery_notes.review_acceptance was added after the Admin group's
  # permission set was frozen into CreateGroupsAndTeams::ADMIN_PERMISSIONS.
  # Fresh installs pick it up via db/seeds.rb (which grants every current
  # Permission::ALL_KEYS), but installs upgraded by `db:migrate` alone never
  # got the row — so the acceptance-review card stayed hidden for everyone,
  # admins included. Backfill it here.
  #
  # Literals are intentional: migrations stay self-contained and don't depend
  # on app constants (Permission / Group::ADMIN_NAME) that may later rename.
  PERMISSION = "delivery_notes.review_acceptance".freeze

  class MigrationGroup < ActiveRecord::Base
    self.table_name = "groups"
    has_many :group_permissions,
             class_name: "GrantReviewAcceptanceToAdminGroup::MigrationGroupPermission",
             foreign_key: :group_id
  end

  class MigrationGroupPermission < ActiveRecord::Base
    self.table_name = "group_permissions"
  end

  def up
    admin = MigrationGroup.find_by(builtin: true, name: "Admin")
    return unless admin

    admin.group_permissions.find_or_create_by!(permission: PERMISSION)
  end

  def down
    # No-op: the permission legitimately belongs to the Admin group on every
    # current install, so removing it on rollback would reintroduce the bug.
  end
end
