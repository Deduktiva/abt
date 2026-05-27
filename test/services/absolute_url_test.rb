require "test_helper"

class AbsoluteUrlTest < ActiveSupport::TestCase
  setup do
    @original = {
      host: Settings.app.host,
      protocol: Settings.app.protocol,
      script_name: Settings.app.script_name
    }
  end

  teardown do
    Settings.app.host = @original[:host]
    Settings.app.protocol = @original[:protocol]
    Settings.app.script_name = @original[:script_name]
  end

  test "invite URL includes host, protocol, and script_name from Settings" do
    Settings.app.host = "example.test"
    Settings.app.protocol = "https"
    Settings.app.script_name = "/abt"

    url = AbsoluteUrl.invite("tok-123")

    assert_equal "https://example.test/abt/invites?token=tok-123", url
  end

  test "invite URL omits sub-path when script_name is blank" do
    Settings.app.host = "example.test"
    Settings.app.protocol = "https"
    Settings.app.script_name = ""

    url = AbsoluteUrl.invite("tok-123")

    assert_equal "https://example.test/invites?token=tok-123", url
  end

  test "account_email_confirmation URL includes script_name from Settings" do
    Settings.app.host = "example.test"
    Settings.app.protocol = "https"
    Settings.app.script_name = "/abt"

    url = AbsoluteUrl.account_email_confirmation("tok-xyz")

    assert_equal "https://example.test/abt/account/email_confirmations?token=tok-xyz", url
  end
end
