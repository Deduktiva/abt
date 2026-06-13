require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires username, full name" do
    user = User.new
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
    assert_includes user.errors[:full_name], "can't be blank"
  end

  test "admin? is true only for members of the builtin Admin group" do
    assert users(:alice).admin?
    assert_not users(:bob).admin?
  end

  test "auto-assigns webauthn_id on create" do
    user = User.new(username: "newone", full_name: "New User")
    assert user.valid?
    assert user.webauthn_id.present?
  end

  test "username is unique case-insensitively" do
    User.create!(username: "newone", full_name: "New User")
    dup = User.new(username: "NewOne", full_name: "Other")
    assert_not dup.valid?
  end

  test "username format is enforced" do
    user = User.new(username: "has spaces", full_name: "X")
    assert_not user.valid?
    assert_includes user.errors[:username], "is invalid"
  end

  test "username accepts unicode letters" do
    user = User.new(username: "ärnö", full_name: "Ärnö Müller")
    assert user.valid?, user.errors.full_messages.inspect
    user.save!
    assert_equal "ärnö", user.reload.username
  end

  test "username accepts non-latin letters" do
    user = User.new(username: "宮本", full_name: "Miyamoto")
    assert user.valid?, user.errors.full_messages.inspect
  end

  test "blocked? reflects blocked_at" do
    assert_not users(:alice).blocked?
    assert users(:blocked_carol).blocked?
  end

  test "active and blocked scopes" do
    assert_includes User.active.to_a, users(:alice)
    assert_not_includes User.active.to_a, users(:blocked_carol)
    assert_includes User.blocked.to_a, users(:blocked_carol)
  end

  test "confirmed_emails returns only confirmed addresses" do
    alice = users(:alice)
    assert_equal 2, alice.confirmed_emails.count
    pending = alice.emails.create!(address: "pending@example.com")
    assert_not_includes alice.confirmed_emails.reload, pending
  end

  test "block! sets fields, terminates sessions, records audit" do
    alice = users(:alice)
    bob = users(:bob)
    sess, _plaintext = UserSession.create_for!(user: alice, request: nil)
    active_count_before = alice.sessions.active.count

    assert_difference -> { UserAuditEvent.where(action: "blocked").count }, 1 do
      assert_difference -> { UserAuditEvent.where(action: "session_terminated").count }, active_count_before do
        alice.block!(reason: "testing", actor: bob)
      end
    end

    alice.reload
    assert alice.blocked?
    assert_equal "testing", alice.blocked_reason
    assert_equal bob, alice.blocked_by_user
    assert sess.reload.terminated_at.present?
  end

  test "unblock! clears block fields and records audit" do
    carol = users(:blocked_carol)
    alice = users(:alice)
    assert_difference -> { UserAuditEvent.where(action: "unblocked").count }, 1 do
      carol.unblock!(actor: alice, reason: "admin_unblock")
    end
    carol.reload
    assert_not carol.blocked?
  end

  test "reset_passkeys! destroys credentials, terminates sessions, returns invite" do
    alice = users(:alice)
    bob = users(:bob)
    UserSession.create_for!(user: alice, request: nil)
    assert alice.credentials.exists?

    invite, plaintext = nil
    assert_difference -> { UserInvite.count }, 1 do
      assert_difference -> { UserAuditEvent.where(action: "passkey_reset").count }, 1 do
        invite, plaintext = alice.reset_passkeys!(actor: bob)
      end
    end

    assert_empty alice.reload.credentials
    assert_equal UserInvite::PURPOSE_PASSKEY_RESET, invite.purpose
    assert_equal alice, invite.target_user
    assert plaintext.length > 20
  end
end
