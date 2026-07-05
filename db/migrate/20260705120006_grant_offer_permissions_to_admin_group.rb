class GrantOfferPermissionsToAdminGroup < ActiveRecord::Migration[8.1]
  PERMISSIONS = %w[offers.view offers.edit offers.convert].freeze

  class MigrationGroup < ActiveRecord::Base
    self.table_name = "groups"
    has_many :group_permissions, class_name: "GrantOfferPermissionsToAdminGroup::MigrationGroupPermission", foreign_key: :group_id
  end

  class MigrationGroupPermission < ActiveRecord::Base
    self.table_name = "group_permissions"
  end

  def up
    admin = MigrationGroup.find_by(builtin: true, name: "Admin")
    return unless admin
    PERMISSIONS.each { |p| admin.group_permissions.find_or_create_by!(permission: p) }
  end

  def down; end
end
