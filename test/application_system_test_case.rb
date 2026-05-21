require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, using: :chrome, screen_size: [1400, 1400], options: {
    js_errors: true,
    headless: ENV['HEADLESS'] != '0'  # Default to headless unless explicitly disabled
  }

  setup do
    if User.exists?(username: "alice") && !self.class.name.start_with?("InviteSignup")
      capybara_sign_in_as(users(:alice))
    end
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  # Drives the real /login → /auth/github → callback flow in the browser using
  # OmniAuth test mode. After this returns, the Capybara session holds a real
  # encrypted session cookie for the given user.
  def capybara_sign_in_as(user)
    identity = user.identities.find_by(provider: "github")
    identity ||= user.identities.create!(
      provider: "github",
      uid: "test-#{user.id}",
      nickname: user.username,
      email: "#{user.username}@test.local",
      raw_info: {}
    )

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: identity.uid,
      info: { nickname: user.username, name: user.full_name, email: identity.email }
    )

    visit "/login"
    click_button "Continue with GitHub"
  end
end
