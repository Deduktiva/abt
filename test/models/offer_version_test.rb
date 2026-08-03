require "test_helper"

class OfferVersionTest < ActiveSupport::TestCase
  test "recalculate_sum_net! tracks milestone amounts on a draft version" do
    version = offer_versions(:draft_offer_v1)
    version.milestones.create!(title: "Rollout", amount: 250, trigger: "on_acceptance", position: 2)
    assert_equal 750, version.reload.sum_net
  end

  test "recalculate_sum_net! leaves a sent version's quoted sum alone" do
    milestone = offer_milestones(:sent_ms_one)
    version = milestone.offer_version
    version.update_columns(sum_net: 12345)

    milestone.update!(invoice: invoices(:draft_invoice))

    assert_equal 12345, version.reload.sum_net
  end
end
