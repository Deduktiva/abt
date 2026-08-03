class GroupMembership < ApplicationRecord
  belongs_to :group
  belongs_to :user

  validates :user_id, uniqueness: { scope: :group_id }

  before_destroy :prevent_removing_last_admin

  private

  # Defence in depth only: the controllers use collection assignment, whose
  # `delete_all` never reaches this callback. AdminFloor holds that line.
  def prevent_removing_last_admin
    return unless group.admin?
    if group.users.active.where.not(id: user_id).none?
      errors.add(:base, "Cannot remove the last active member of the Admin group")
      throw :abort
    end
  end
end
