module InvoicesHelper
  def invoice_payment_status_badge_tag(invoice)
    label, badge_class = invoice.payment_status_badge
    return unless label

    content_tag(:span, label, class: "badge #{badge_class}")
  end
end
