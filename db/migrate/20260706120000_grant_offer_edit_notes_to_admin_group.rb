class GrantOfferEditNotesToAdminGroup < ActiveRecord::Migration[8.1]
  PERMISSION = "offers.edit_notes".freeze

  class MigrationGroup < ActiveRecord::Base
    self.table_name = "groups"
    has_many :group_permissions, class_name: "GrantOfferEditNotesToAdminGroup::MigrationGroupPermission", foreign_key: :group_id
  end

  class MigrationGroupPermission < ActiveRecord::Base
    self.table_name = "group_permissions"
  end

  def up
    admin = MigrationGroup.find_by(builtin: true, name: "Admin")
    return unless admin
    admin.group_permissions.find_or_create_by!(permission: PERMISSION)
  end

  def down; end
end
