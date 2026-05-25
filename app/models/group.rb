class Group < ApplicationRecord
  # Name of the built-in administrator group. Referenced by Group#admin?,
  # User#auto_promote_first_user, UsersController#update_groups (last-admin
  # protection), and the seed migration. The string lives here so any future
  # rename is a single edit; prevent_name_change_if_builtin keeps the row's
  # actual name in sync with this constant.
  ADMIN_NAME = "Admin".freeze

  has_many :group_memberships, dependent: :destroy
  has_many :users, through: :group_memberships
  has_many :group_permissions, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 60 }
  validates :description, length: { maximum: 200 }
  validate :prevent_name_change_if_builtin

  before_destroy :prevent_destroy_if_builtin, prepend: true

  scope :ordered, -> { order(:name) }

  def self.admin
    find_by(builtin: true, name: ADMIN_NAME)
  end

  def permissions
    @permissions ||= group_permissions.pluck(:permission).to_set
  end

  def permission?(key)
    permissions.include?(key)
  end

  # Sync the set of permissions assigned to this group.
  # - Unknown keys are silently dropped.
  # - Admin-only keys (users.reset_passkeys, users.auto_confirm_email) are
  #   silently dropped for non-Admin groups; GroupPermission's validation is
  #   the loud defense-in-depth that catches direct DB-style attempts.
  def permissions=(keys)
    keys = Array(keys).select { |k| Permission.valid?(k) }
    keys -= Permission::ADMIN_ONLY_KEYS.to_a unless admin?
    keys = keys.to_set
    transaction do
      existing = group_permissions.pluck(:permission).to_set
      (existing - keys).each do |p|
        group_permissions.where(permission: p).destroy_all
      end
      (keys - existing).each do |p|
        group_permissions.create!(permission: p)
      end
    end
    @permissions = nil
  end

  def admin?
    builtin? && name == ADMIN_NAME
  end

  private

  # Renaming a built-in group would silently break the security model.
  # admin? checks `builtin? && name == ADMIN_NAME`, so a rename disables the
  # last-admin protection, admin-only permission validation, and the
  # permission filter. Block at the model layer so even direct
  # ActiveRecord updates (console, jobs) can't do it.
  def prevent_name_change_if_builtin
    return unless persisted? && builtin? && will_save_change_to_name?
    errors.add(:name, "of a built-in group cannot be changed")
  end

  def prevent_destroy_if_builtin
    if builtin?
      errors.add(:base, "Cannot delete a built-in group")
      throw :abort
    end
  end
end
