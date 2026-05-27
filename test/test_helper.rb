ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"

# System testing with Capybara
require "capybara/rails"
require "capybara/minitest"
require "capybara/cuprite"

# Configure better waiting behavior
Capybara.default_max_wait_time = 10
Capybara.ignore_hidden_elements = true

# Automatically apply migrations to test database
ActiveRecord::Migration.maintain_test_schema!

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  include DocumentFactories

  # Make sure no test accidentally talks to the live VIES SOAP endpoint.
  # Tests that exercise the verifier must set their own lookup_strategy.
  setup do
    ViesVerifier.lookup_strategy = ->(*) { raise "VIES called without stub" } if defined?(ViesVerifier)
  end
end

module TestAuthHelpers
  extend ActiveSupport::Concern

  class_methods do
    def skip_default_signin!
      self._skip_default_signin = true
    end
  end

  included do
    class_attribute :_skip_default_signin, default: false

    setup do
      sign_in_as(users(:alice)) unless self.class._skip_default_signin
    end
  end

  def sign_in_as(user, request_obj = nil)
    request_obj ||= Struct.new(:remote_ip, :user_agent).new("127.0.0.1", "test")
    session_record, plaintext = UserSession.create_for!(user: user, request: request_obj)
    if is_a?(ActionDispatch::SystemTestCase)
      visit "/" if page.current_url.blank? || page.current_url == "about:blank"
      page.driver.set_cookie(ApplicationController::AUTH_COOKIE.to_s, plaintext)
    else
      cookies[ApplicationController::AUTH_COOKIE] = plaintext
    end
    session_record
  end
end

class ActionDispatch::IntegrationTest
  include TestAuthHelpers
end

class ActionDispatch::SystemTestCase
  include TestAuthHelpers
end
