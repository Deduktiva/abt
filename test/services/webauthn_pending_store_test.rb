require "test_helper"

class WebauthnPendingStoreTest < ActiveSupport::TestCase
  setup do
    @session = {}
  end

  test "write then consume returns the payload with string keys" do
    WebauthnPendingStore.write(session: @session, flow: :login, challenge: "abc")
    pending = WebauthnPendingStore.consume(session: @session, flow: :login)
    assert_equal({ "challenge" => "abc" }, pending)
  end

  test "consume deletes the session nonce" do
    WebauthnPendingStore.write(session: @session, flow: :login, challenge: "abc")
    assert @session[:webauthn_login_nonce].present?
    WebauthnPendingStore.consume(session: @session, flow: :login)
    assert_nil @session[:webauthn_login_nonce]
  end

  test "second consume returns nil (single-use)" do
    WebauthnPendingStore.write(session: @session, flow: :login, challenge: "abc")
    WebauthnPendingStore.consume(session: @session, flow: :login)
    assert_nil WebauthnPendingStore.consume(session: @session, flow: :login)
  end

  test "consume on empty session returns nil" do
    assert_nil WebauthnPendingStore.consume(session: @session, flow: :login)
  end

  test "payload expires after TTL" do
    WebauthnPendingStore.write(session: @session, flow: :login, challenge: "abc")
    travel WebauthnPendingStore::TTL + 1.second do
      assert_nil WebauthnPendingStore.consume(session: @session, flow: :login)
    end
  end

  test "different flows are isolated" do
    WebauthnPendingStore.write(session: @session, flow: :login, challenge: "login-c")
    WebauthnPendingStore.write(session: @session, flow: :signup, challenge: "signup-c")

    login = WebauthnPendingStore.consume(session: @session, flow: :login)
    signup = WebauthnPendingStore.consume(session: @session, flow: :signup)

    assert_equal "login-c", login["challenge"]
    assert_equal "signup-c", signup["challenge"]
  end
end
