class GrantOfferPermissionsToAdminGroup < ActiveRecord::Migration[8.0]
  OFFER_PERMISSIONS = %w[offers.view offers.edit offers.convert].freeze

  def up
    admin = Group.find_by(name: "Admin")
    return unless admin

    now = Time.current
    OFFER_PERMISSIONS.each do |perm|
      GroupPermission.find_or_create_by(group_id: admin.id, permission: perm) do |row|
        row.created_at = now
        row.updated_at = now
      end
    end
  end

  def down
    admin = Group.find_by(name: "Admin")
    return unless admin
    GroupPermission.where(group_id: admin.id, permission: OFFER_PERMISSIONS).delete_all
  end
end
