require "test_helper"

class UserSessionTest < ActiveSupport::TestCase
  def fake_request
    Struct.new(:remote_ip, :user_agent).new("203.0.113.1", "TestUA")
  end

  test "create_for! returns plaintext and stores only digest" do
    session, plaintext = UserSession.create_for!(user: users(:alice), request: fake_request)
    assert plaintext.length > 20
    assert_equal Digest::SHA256.hexdigest(plaintext), session.token_digest
    assert_equal "203.0.113.1", session.ip_address
  end

  test "authenticate matches by digest of plaintext" do
    _session, plaintext = UserSession.create_for!(user: users(:alice), request: fake_request)
    assert UserSession.authenticate(plaintext)
    assert_nil UserSession.authenticate("wrong-token")
    assert_nil UserSession.authenticate(nil)
  end

  test "active scope excludes terminated and expired" do
    session, _plaintext = UserSession.create_for!(user: users(:alice), request: fake_request)
    assert_includes UserSession.active.to_a, session
    session.update_column(:last_seen_at, 31.days.ago)
    assert_not_includes UserSession.active.to_a, session
  end

  test "terminate! sets fields and records audit" do
    session, _plain = UserSession.create_for!(user: users(:alice), request: fake_request)
    assert_difference -> { UserAuditEvent.where(action: "session_terminated").count }, 1 do
      session.terminate!(reason: "logout", actor: users(:alice))
    end
    assert session.terminated_at.present?
    assert_equal "logout", session.termination_reason
    assert_not session.active?
  end

  test "touch_seen! updates last_seen_at" do
    session, _plain = UserSession.create_for!(user: users(:alice), request: fake_request)
    session.update_column(:last_seen_at, 1.hour.ago)
    session.touch_seen!(fake_request)
    assert_in_delta Time.current.to_f, session.reload.last_seen_at.to_f, 5
  end
end
