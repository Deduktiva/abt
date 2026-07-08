require "application_system_test_case"

# Regression tests for the responsive mobile layout. The viewport meta tag is
# what makes mobile browsers lay pages out at device width instead of a ~980px
# virtual desktop viewport; without it Bootstrap's breakpoints never trigger on
# phones (no burger menu, desktop-sized pages). Plain window resizing cannot
# catch that regression -- desktop browsers ignore the viewport meta -- so
# these tests use Chrome's mobile device emulation via CDP.
class MobileLayoutTest < ApplicationSystemTestCase
  IPHONE = { width: 390, height: 844, deviceScaleFactor: 3, mobile: true }.freeze

  teardown do
    cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "app layout lays out at device width on a phone" do
    emulate_iphone
    visit root_path

    assert page.find("meta[name='viewport']", visible: false)[:content].include?("width=device-width")

    layout_width = page.evaluate_script("document.documentElement.clientWidth")
    assert_operator layout_width, :<=, IPHONE[:width],
      "expected mobile layout viewport of ~#{IPHONE[:width]}px, got #{layout_width}px " \
      "(980px means the viewport meta tag is missing or ignored)"
  end

  test "navbar collapses to a burger menu on a phone" do
    emulate_iphone
    visit root_path

    assert_selector ".navbar-toggler", visible: true
    assert_no_selector ".navbar-collapse.show"
    assert_no_selector ".navbar-nav .nav-link", text: "Invoices"

    find(".navbar-toggler").click
    assert_selector ".navbar-collapse.show"
    assert_selector ".navbar-nav .nav-link", text: "Invoices"
  end

  test "customer portal lays out at device width on a phone" do
    prev_app_host = Capybara.app_host
    prev_include_port = Capybara.always_include_port
    Capybara.app_host = "http://#{Settings.customer_portal.host}"
    Capybara.always_include_port = true

    emulate_iphone
    visit public_root_path

    layout_width = page.evaluate_script("document.documentElement.clientWidth")
    assert_operator layout_width, :<=, IPHONE[:width],
      "expected mobile layout viewport of ~#{IPHONE[:width]}px, got #{layout_width}px " \
      "(980px means the viewport meta tag is missing or ignored)"
  ensure
    Capybara.app_host = prev_app_host
    Capybara.always_include_port = prev_include_port
  end

  private

  def emulate_iphone
    cdp("Emulation.setDeviceMetricsOverride", **IPHONE)
  end

  def cdp(method, **params)
    page.driver.browser.page.command(method, **params)
  end
end
