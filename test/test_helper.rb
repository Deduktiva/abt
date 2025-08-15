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
