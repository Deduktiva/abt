require "application_system_test_case"

class CustomerFilterTest < ApplicationSystemTestCase
  test "invoice index customer dropdown expands on focus" do
    Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "FILTER-TEST",
      date: Date.current
    )

    visit invoices_url

    select_css = "select[name='customer_id']"
    assert_selector select_css

    good_eu = customers(:good_eu)
    option_selector = "#{select_css} option[value='#{good_eu.id}']"
    expected_full = "#{good_eu.matchcode} — #{good_eu.name}"

    # Closed state: option text is matchcode only.
    assert_equal good_eu.matchcode, page.evaluate_script("document.querySelector(#{option_selector.to_json}).text")

    # The Stimulus action listens for focus on the select.
    page.execute_script(<<~JS)
      const el = document.querySelector(#{select_css.to_json});
      el.dispatchEvent(new Event('focus', { bubbles: true }));
    JS

    assert_equal expected_full, page.evaluate_script("document.querySelector(#{option_selector.to_json}).text")

    # Blur collapses back to matchcode.
    page.execute_script(<<~JS)
      const el = document.querySelector(#{select_css.to_json});
      el.dispatchEvent(new Event('blur', { bubbles: true }));
    JS

    assert_equal good_eu.matchcode, page.evaluate_script("document.querySelector(#{option_selector.to_json}).text")
  end
end
