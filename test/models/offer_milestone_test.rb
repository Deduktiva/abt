require "test_helper"

class OfferMilestoneTest < ActiveSupport::TestCase
  test "trigger must be one of the known values" do
    m = offer_milestones(:sent_ms_one)
    m.trigger = "bogus"
    assert_not m.valid?
  end

  test "on_date trigger requires a date" do
    m = offer_milestones(:sent_ms_one)
    m.trigger = "on_date"
    m.trigger_date = nil
    assert_not m.valid?
  end

  test "saving milestones updates the version sum_net" do
    version = offer_versions(:draft_offer_v1)
    version.milestones.create!(title: "Extra", amount: 100, trigger: "on_acceptance", position: 9)
    assert_equal version.milestones.sum(:amount), version.reload.sum_net
  end

  test "default_skip_delivery_note true only for on_order" do
    m = OfferMilestone.new(trigger: "on_order")
    assert m.default_skip_delivery_note
    m.trigger = "on_acceptance"
    assert_not m.default_skip_delivery_note
  end
end
