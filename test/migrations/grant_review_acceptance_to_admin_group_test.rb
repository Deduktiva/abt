require "test_helper"
require Rails.root.join("db/migrate/20260613120000_grant_review_acceptance_to_admin_group")

class GrantReviewAcceptanceToAdminGroupTest < ActiveSupport::TestCase
  PERMISSION = "delivery_notes.review_acceptance".freeze

  def admin_has_permission?
    # Fresh instance each call: Group#permissions memoizes in an ivar that
    # reload doesn't clear, so reusing one object would mask the change.
    Group.find(groups(:admin).id).permission?(PERMISSION)
  end

  test "backfills the permission on an Admin group that lacks it" do
    groups(:admin).group_permissions.where(permission: PERMISSION).delete_all
    assert_not admin_has_permission?

    GrantReviewAcceptanceToAdminGroup.new.up

    assert admin_has_permission?
  end

  test "is idempotent when the permission already exists" do
    GrantReviewAcceptanceToAdminGroup.new.up
    assert_equal 1, groups(:admin).group_permissions.where(permission: PERMISSION).count
  end
end
