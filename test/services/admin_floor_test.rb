require "test_helper"

class AdminFloorTest < ActiveSupport::TestCase
  test "rolls back a mutation that leaves the Admin group empty" do
    assert_raises(AdminFloor::Violation) do
      AdminFloor.protect! { groups(:admin).group_memberships.delete_all }
    end
    assert_includes groups(:admin).reload.users, users(:alice)
  end

  test "blocked members do not satisfy the floor" do
    groups(:admin).users << users(:blocked_carol)
    assert_raises(AdminFloor::Violation) do
      AdminFloor.protect! { users(:alice).groups = [] }
    end
    assert_includes groups(:admin).reload.users, users(:alice)
  end

  test "allows a removal that leaves another active admin behind" do
    groups(:admin).users << users(:bob)
    AdminFloor.protect! { users(:alice).groups = [] }
    assert_equal [ users(:bob) ], groups(:admin).reload.users.to_a
  end

  test "allows unrelated mutations when the Admin group is already empty" do
    groups(:admin).group_memberships.delete_all
    AdminFloor.protect! { users(:bob).groups = [ groups(:sales) ] }
    assert_includes users(:bob).reload.groups, groups(:sales)
  end

  test "returns the block's value" do
    assert_equal :done, AdminFloor.protect! { :done }
  end
end
