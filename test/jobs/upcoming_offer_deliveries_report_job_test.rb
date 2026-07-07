require "test_helper"

class UpcomingOfferDeliveriesReportJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @offer = offers(:sent_offer)
    @offer.accept!(order_number: "PO-77", ordered_on: Date.current)
    @offer.accepted_version.update!(delivery_date: Date.current + 3)
  end

  test "reports a nearing delivery with unconverted milestones in one digest" do
    assert_emails 1 do
      UpcomingOfferDeliveriesReportJob.perform_now
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ IssuerCompany.get_the_issuer!.reporting_email ], mail.to
    [ mail.html_part.body.to_s, mail.text_part.body.to_s ].each do |body|
      assert_match @offer.document_number, body
      assert_match @offer.customer.name, body
      assert_match @offer.accepted_version.delivery_date.strftime("%d.%m.%Y"), body
      assert_match "2 milestones not converted", body
    end
  end

  test "links the offer number to the offer detail page" do
    UpcomingOfferDeliveriesReportJob.perform_now
    mail = ActionMailer::Base.deliveries.last
    offer_url = AbsoluteUrl.offer(@offer)
    assert_match %r{href="#{Regexp.escape(offer_url)}"}, mail.html_part.body.to_s
    assert_match offer_url, mail.text_part.body.to_s
  end

  test "distinguishes unbooked and unsent invoices in the status" do
    offer_milestones(:sent_ms_one).update!(invoice: build_invoice(published: false))
    offer_milestones(:sent_ms_two).update!(invoice: build_invoice(published: true))
    assert_emails 1 do
      UpcomingOfferDeliveriesReportJob.perform_now
    end
    body = ActionMailer::Base.deliveries.last.text_part.body.to_s
    assert_match "1 invoice not booked", body
    assert_match "1 invoice not sent", body
    assert_no_match(/not converted/, body)
  end

  test "no-op when every milestone has a booked and sent invoice" do
    offer_milestones(:sent_ms_one).update!(invoice: build_invoice(published: true, sent: true))
    offer_milestones(:sent_ms_two).update!(invoice: build_invoice(published: true, sent: true))
    assert_emails 0 do
      UpcomingOfferDeliveriesReportJob.perform_now
    end
  end

  test "an overdue delivery date keeps being reported" do
    @offer.accepted_version.update!(delivery_date: Date.yesterday)
    assert_emails 1 do
      UpcomingOfferDeliveriesReportJob.perform_now
    end
  end

  test "reports an unbooked on-order milestone even when delivery is far off" do
    @offer.accepted_version.update!(delivery_date: Date.current + 30)
    # sent_ms_one is an on_order milestone with no invoice
    assert_emails 1 do
      UpcomingOfferDeliveriesReportJob.perform_now
    end
  end

  test "no-op when delivery is far and the on-order milestone is booked" do
    @offer.accepted_version.update!(delivery_date: Date.current + 30)
    offer_milestones(:sent_ms_one).update!(invoice: build_invoice(published: true))
    assert_emails 0 do
      UpcomingOfferDeliveriesReportJob.perform_now
    end
  end

  test "a non-accepted offer is ignored even with a nearing delivery date" do
    @offer.accepted_version.update!(delivery_date: Date.current + 30)
    offer_milestones(:sent_ms_one).update!(invoice: build_invoice(published: true))
    offers(:draft_offer).draft_version.update!(delivery_date: Date.current)
    assert_emails 0 do
      UpcomingOfferDeliveriesReportJob.perform_now
    end
  end

  private

  def build_invoice(published:, sent: false)
    Invoice.create!(customer: @offer.customer, project: @offer.project,
                    customer_country_iso2: @offer.customer.country_iso2,
                    date: Date.current, published: published,
                    email_sent_at: (Time.current if sent))
  end
end
