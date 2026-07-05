require "test_helper"

class OfferMilestoneScaffolderTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:good_eu)
    @customer.update!(
      offer_milestone_split_threshold: 10_000,
      offer_milestone_templates_below: "Full amount|on_acceptance|100",
      offer_milestone_templates_above: "Deposit|on_order|30\nDelivery|on_acceptance|70"
    )
    @version = create_draft_offer(customer: @customer).draft_version
  end

  test "below threshold uses the below list" do
    rows = OfferMilestoneScaffolder.new(@customer, 5000).apply_to(@version)
    assert_equal [ "Full amount" ], rows.map(&:title)
    assert_equal [ 5000 ], rows.map(&:amount)
  end

  test "above threshold distributes proportionally with the last row absorbing rounding" do
    rows = OfferMilestoneScaffolder.new(@customer, 10_001).apply_to(@version)
    assert_equal %w[Deposit Delivery], rows.map(&:title)
    assert_equal 10_001, rows.sum(&:amount)
    assert_equal (10_001 * 0.3).round(2), rows.first.amount
  end

  test "on_order rows default to skipping the delivery note" do
    rows = OfferMilestoneScaffolder.new(@customer, 20_000).apply_to(@version)
    assert rows.first.skip_delivery_note
    assert_not rows.last.skip_delivery_note
  end

  test "malformed lines are skipped; nothing parseable falls back to a single placeholder" do
    @customer.update!(offer_milestone_templates_below: "garbage-without-pipes\nAlso|bad")
    rows = OfferMilestoneScaffolder.new(@customer, 100).apply_to(@version)
    assert_equal [ "Milestone" ], rows.map(&:title)
    assert_equal [ 100 ], rows.map(&:amount)
  end

  test "no threshold always uses the below list" do
    @customer.update!(offer_milestone_split_threshold: nil)
    rows = OfferMilestoneScaffolder.new(@customer, 50_000).apply_to(@version)
    assert_equal [ "Full amount" ], rows.map(&:title)
    assert_equal [ 50_000 ], rows.map(&:amount)
  end

  test "blank templates fall back to a single placeholder" do
    @customer.update!(offer_milestone_split_threshold: nil,
                      offer_milestone_templates_below: "",
                      offer_milestone_templates_above: "")
    rows = OfferMilestoneScaffolder.new(@customer, 100).apply_to(@version)
    assert_equal [ "Milestone" ], rows.map(&:title)
  end

  test "refuses when the draft already has milestones" do
    @version.milestones.create!(title: "Existing", amount: 1, trigger: "on_acceptance", position: 1)
    assert_raises(OfferMilestoneScaffolder::MilestonesPresent) do
      OfferMilestoneScaffolder.new(@customer, 100).apply_to(@version)
    end
  end

  test "on_date template rows scaffold with today's date as an editable placeholder" do
    @customer.update!(
      offer_milestone_templates_below: "Kickoff|on_date|100"
    )
    rows = OfferMilestoneScaffolder.new(@customer, 100).apply_to(@version)
    assert_equal [ "on_date" ], rows.map(&:trigger)
    assert_equal Date.current, rows.first.trigger_date
  end

  test "three-row template distributes proportionally and the last row absorbs rounding" do
    @customer.update!(
      offer_milestone_templates_above: "A|on_acceptance|33.3\nB|on_acceptance|33.3\nC|on_acceptance|33.4"
    )
    rows = OfferMilestoneScaffolder.new(@customer, 10_000).apply_to(@version)
    assert_equal 3, rows.length
    assert_equal %w[A B C], rows.map(&:title)
    assert_equal 10_000, rows.sum(&:amount)
    expected_first_two = (BigDecimal("10000") * BigDecimal("33.3") / 100).round(2)
    assert_equal expected_first_two, rows[0].amount
    assert_equal expected_first_two, rows[1].amount
    assert_equal 10_000 - expected_first_two - expected_first_two, rows[2].amount
  end
end
