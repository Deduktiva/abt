require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  cuprite_options = {
    js_errors: true,
    headless: ENV['HEADLESS'] != '0'  # Default to headless unless explicitly disabled
  }

  # Allow pointing at a non-standard Chromium binary (e.g. the Playwright build
  # in /opt/pw-browsers in our sandbox) and add --no-sandbox when running as
  # root, which Chrome refuses by default.
  if ENV['BROWSER_PATH'].present?
    if File.executable?(ENV['BROWSER_PATH'])
      cuprite_options[:browser_path] = ENV['BROWSER_PATH']
    else
      warn "WARNING: BROWSER_PATH=#{ENV['BROWSER_PATH']} is not executable; falling back to cuprite's default chrome lookup."
    end
  end
  if Process.uid.zero? || ENV['CHROME_NO_SANDBOX'] == '1'
    cuprite_options[:browser_options] = { 'no-sandbox' => nil }
  end

  driven_by :cuprite, using: :chrome, screen_size: [1400, 1400], options: cuprite_options
end
