require "test_helper"

# Proves the verify_permission_check_performed after_action catches controllers
# that forget to declare a permission gate or an explicit opt-out.
class PermissionCheckVerificationTest < ActionDispatch::IntegrationTest
  class ForgotPermissionCheckController < ApplicationController
    def index
      render plain: "should never reach here"
    end
  end

  setup do
    Rails.application.routes.draw do
      get "forgot_permission_check_test/index",
          to: "permission_check_verification_test/forgot_permission_check#index"
      get "/" => "home#index", as: :root
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "after_action raises MissingPermissionCheck if action did not gate" do
    assert_raises(ApplicationController::MissingPermissionCheck) do
      get "/forgot_permission_check_test/index"
    end
  end
end
