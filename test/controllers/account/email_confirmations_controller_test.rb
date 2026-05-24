require "test_helper"

class Account::EmailConfirmationsControllerTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test "confirms an email with a valid token" do
    email = users(:alice).emails.create!(address: "newconfirm@example.com")
    plaintext = email.generate_confirmation_token!

    get account_email_confirmation_path(token: plaintext)
    assert_response :redirect
    assert email.reload.confirmed?
  end

  test "rejects an invalid token" do
    get account_email_confirmation_path(token: "nope")
    assert_response :redirect
    follow_redirect!
    assert_match(/invalid or expired/i, flash[:alert] || "")
  end

  test "rejects an expired token" do
    email = users(:alice).emails.create!(address: "exp@example.com")
    plaintext = email.generate_confirmation_token!
    email.update_column(:confirmation_expires_at, 1.minute.ago)

    get account_email_confirmation_path(token: plaintext)
    assert_response :redirect
    assert_not email.reload.confirmed?
  end

  test "records an audit event on confirmation" do
    email = users(:alice).emails.create!(address: "audit@example.com")
    plaintext = email.generate_confirmation_token!

    assert_difference -> { UserAuditEvent.where(action: "email_confirmed").count }, 1 do
      get account_email_confirmation_path(token: plaintext)
    end
  end
end
