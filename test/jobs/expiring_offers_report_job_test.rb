require "test_helper"

class ExpiringOffersReportJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def make_sent_offer(expires_at:, matchcode: "exp-#{SecureRandom.hex(3)}")
    offer = Offer.create_with_initial_version!(
      matchcode: matchcode,
      customer: customers(:good_eu),
      project: projects(:one),
      state: "draft"
    )
    offer.current_version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 1)
    offer.send_current_version!
    offer.update_columns(expires_at: expires_at)
    offer
  end

  test "expires offers past their expires_at and sends one digest" do
    expired_offer = make_sent_offer(expires_at: 1.day.ago)
    fresh_offer = make_sent_offer(expires_at: 7.days.from_now)

    assert_emails 1 do
      ExpiringOffersReportJob.new.perform
    end

    assert expired_offer.reload.state_expired?
    assert_not_nil expired_offer.reported_expired_at
    assert fresh_offer.reload.state_sent?
  end

  test "skips offers already reported" do
    already_reported = make_sent_offer(expires_at: 5.days.ago)
    already_reported.update_columns(state: "expired", reported_expired_at: 1.day.ago)

    assert_no_emails do
      ExpiringOffersReportJob.new.perform
    end
  end

  test "no email when there are no expiring offers" do
    make_sent_offer(expires_at: 7.days.from_now)
    assert_no_emails do
      ExpiringOffersReportJob.new.perform
    end
  end
end
