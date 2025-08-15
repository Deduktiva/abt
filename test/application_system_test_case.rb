require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if ENV['HEADLESS'] == '1'
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  else
    driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
  end
end
