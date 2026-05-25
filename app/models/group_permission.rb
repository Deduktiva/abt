class GroupPermission < ApplicationRecord
  belongs_to :group

  validates :permission, presence: true, uniqueness: { scope: :group_id }
  validate  :permission_must_be_known
  validate  :admin_only_permission_only_on_admin_group

  private

  def permission_must_be_known
    return if permission.blank?
    unless Permission.valid?(permission)
      errors.add(:permission, "is not a known permission")
    end
  end

  # Admin-only permissions (users.reset_passkeys, users.auto_confirm_email)
  # carry latent admin-equivalent power. They must never be assigned to a
  # non-Admin group. The seed migration is allowed because it creates the
  # Admin group itself before this validation fires; from then on this is
  # the canonical enforcement point.
  def admin_only_permission_only_on_admin_group
    return if permission.blank?
    return unless Permission.admin_only?(permission)
    return if group&.admin?
    errors.add(:permission, "#{permission} can only be granted to the built-in Admin group")
  end
end
