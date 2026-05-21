ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

# System testing with Capybara
require 'capybara/rails'
require 'capybara/minitest'
require 'capybara/cuprite'

# Configure better waiting behavior
Capybara.default_max_wait_time = 10
Capybara.ignore_hidden_elements = true

# Automatically apply migrations to test database
ActiveRecord::Migration.maintain_test_schema!

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  fixtures :all
end

module SignInHelper
  # Signs the test session in as `user` by driving the real OmniAuth callback.
  # This exercises the actual login codepath and produces a valid encrypted
  # session cookie without having to reach into Rails' encryption internals.
  def sign_in_as(user)
    identity = user.identities.find_by(provider: "github")
    identity ||= user.identities.create!(
      provider: "github",
      uid: "test-#{user.id}",
      nickname: user.username,
      email: "#{user.username}@test.local",
      raw_info: {}
    )

    previous_test_mode = OmniAuth.config.test_mode
    previous_mock = OmniAuth.config.mock_auth[:github]

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: identity.uid,
      info: { nickname: user.username, name: user.full_name, email: identity.email }
    )

    get "/auth/github/callback"
  ensure
    OmniAuth.config.test_mode = previous_test_mode
    OmniAuth.config.mock_auth[:github] = previous_mock
  end

  def sign_out
    delete logout_url
  rescue
    # Tests may call this before any session exists.
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper

  # Default: sign in as alice for every controller test that hasn't been opted
  # out by calling `sign_out` or `sign_in_as(other)`.
  setup do
    skip_auto_signin = %w[SessionsControllerTest InvitesControllerTest]
    if User.exists?(username: "alice") && !skip_auto_signin.include?(self.class.name)
      sign_in_as(users(:alice))
    end
  end
end

# For legacy ActionController::TestCase functional tests, stub the auth
# methods on the @controller instead of round-tripping through OmniAuth.
module ControllerTestSignInHelper
  def stub_signed_in_as(user)
    raw = "func-test-#{user.id}-#{SecureRandom.hex(4)}"
    session_record = UserSession.create!(
      user: user,
      token_digest: UserSession.digest(raw),
      last_seen_at: Time.current,
      user_agent: "func-test",
      ip: "127.0.0.1"
    )
    @controller.define_singleton_method(:current_user) { user }
    @controller.define_singleton_method(:current_session) { session_record }
    @controller.define_singleton_method(:logged_in?) { true }
    @controller.define_singleton_method(:require_login) { true }
    session_record
  end
end

class ActionController::TestCase
  include ControllerTestSignInHelper

  setup do
    stub_signed_in_as(users(:alice)) if User.exists?(username: "alice")
  end
end
