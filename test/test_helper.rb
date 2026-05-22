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
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
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
    request_obj ||= Struct.new(:remote_ip, :user_agent).new('127.0.0.1', 'test')
    session_record, plaintext = UserSession.create_for!(user: user, request: request_obj)
    cookies[ApplicationController::SESSION_COOKIE] = plaintext
    session_record
  end
end

class ActionDispatch::IntegrationTest
  include TestAuthHelpers
end

class ActionController::TestCase
  include TestAuthHelpers
end
