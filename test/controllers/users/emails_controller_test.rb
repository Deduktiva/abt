require "test_helper"

class Users::EmailsControllerTest < ActionDispatch::IntegrationTest
  test "admin can add an email without confirmation" do
    sign_in_as(users(:alice))
    bob = users(:bob)
    assert_difference -> { bob.emails.count }, 1 do
      post user_emails_path(bob), params: { user_email: { address: "bob.new@example.com" } }
    end
    assert_redirected_to user_path(bob)
    new_email = bob.emails.find_by(address: "bob.new@example.com")
    assert new_email.confirmed?
  end

  test "admin can replace an email address" do
    sign_in_as(users(:alice))
    bob = users(:bob)
    primary = bob.emails.first
    put user_email_path(user_id: bob, id: primary), params: { user_email: { address: "bob.replaced@example.com" } }
    assert_redirected_to user_path(bob)
    assert_equal "bob.replaced@example.com", primary.reload.address
    assert primary.confirmed?
  end

  test "admin cannot remove the last confirmed email" do
    sign_in_as(users(:alice))
    bob = users(:bob)
    primary = bob.emails.first
    delete user_email_path(user_id: bob, id: primary)
    assert_redirected_to user_path(bob)
    assert UserEmail.exists?(primary.id)
  end

  test "admin can remove a non-last email" do
    sign_in_as(users(:alice))
    alice = users(:alice)
    secondary = alice.emails.find_by(address: "alice.alt@example.com")
    delete user_email_path(user_id: alice, id: secondary)
    assert_redirected_to user_path(alice)
    assert_not UserEmail.exists?(secondary.id)
  end
end
