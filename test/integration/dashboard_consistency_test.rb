require "test_helper"

class DashboardConsistencyTest < ActionDispatch::IntegrationTest
  test "admin sees a consistency warning when the Admin group is missing a permission" do
    groups(:admin).group_permissions.where(permission: "delivery_notes.review_acceptance").delete_all

    get root_path

    assert_response :success
    assert_select ".alert-warning h5", text: "Admin group is missing permissions"
  end

  test "non-admins never see consistency warnings" do
    groups(:admin).group_permissions.where(permission: "delivery_notes.review_acceptance").delete_all
    sign_in_as users(:bob)

    get root_path

    assert_response :success
    assert_select "h5", text: "Admin group is missing permissions", count: 0
  end
end
