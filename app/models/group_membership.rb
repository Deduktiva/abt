class GroupMembership < ApplicationRecord
  belongs_to :group
  belongs_to :user

  validates :user_id, uniqueness: { scope: :group_id }

  before_destroy :prevent_removing_last_admin

  private

  def prevent_removing_last_admin
    return unless group.admin?
    if group.group_memberships.where.not(id: id).none?
      errors.add(:base, "Cannot remove the last member of the Admin group")
      throw :abort
    end
  end
end
