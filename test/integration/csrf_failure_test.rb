require "test_helper"

# CSRF protection is disabled in the test environment by default
# (config/environments/test.rb). These tests flip it back on so we can
# exercise the rescue_from handler. Each test restores the original value.
class CsrfFailureTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  setup do
    @original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original
  end

  test "JSON request with missing CSRF token returns a user-actionable error" do
    # /session/options is the first call the passkey login JS makes.
    # Without a valid CSRF token, the request must fail with a message
    # the UI can show verbatim to the user.
    post options_session_path, params: {}, as: :json

    assert_response :unprocessable_content
    body = JSON.parse(response.body)
    assert body["error"].present?, "JSON CSRF failures must include an `error` field"
    assert_match(/expired|reload/i, body["error"],
                 "error message should explain the session/token expired and what to do")
  end

  test "HTML form with missing CSRF token renders a friendly session-expired page" do
    # Drive a non-JSON form POST. The login form happens to be JSON-only,
    # so use the sign-out endpoint which is a button_to (HTML POST).
    user = users(:alice)
    sign_in_as(user)

    delete session_path, headers: { "Accept" => "text/html" }

    assert_response :unprocessable_content
    assert_select "h1, h2, h3", text: /session expired/i
    assert_select "a[href]", text: /reload/i
    # No auto-reload: forbid <meta http-equiv="refresh"> and inline scripts
    # that would reload the page without user action.
    assert_select 'meta[http-equiv="refresh"]', false,
                  "must not auto-reload via meta refresh"
    assert_no_match(/location\.reload|location\.href\s*=/i, response.body,
                    "must not auto-reload via JS")
  end
end
