class VatVerificationsReportJob < ApplicationJob
  queue_as :default

  # A customer is "stuck unavailable" when the earliest verification in their
  # current run of transient (valid_response: nil) results is at least this old.
  STUCK_UNAVAILABLE_DAYS = 7

  def perform
    newly_invalid_ids = []
    stuck_unavailable_ids = []
    consumed_ids = []

    eligible_latest_verifications.each do |latest|
      classify(latest, newly_invalid_ids, stuck_unavailable_ids, consumed_ids)
    end

    newly_invalid = CustomerVatVerification.where(id: newly_invalid_ids).includes(:customer).order(:created_at)
    stuck_unavailable = CustomerVatVerification.where(id: stuck_unavailable_ids).includes(:customer).order(:created_at)

    if newly_invalid.any? || stuck_unavailable.any?
      # Deliver synchronously so a delivery failure raises and skips the
      # update_all below — pending rows stay unmarked and the job retries
      # tomorrow. A delivery-then-update_all race could theoretically duplicate
      # the email if update_all then fails, but for a low-volume daily digest
      # to a single human that's an acceptable tradeoff vs. ever silently
      # swallowing a transition.
      VatVerificationsReportMailer.with(
        newly_invalid: newly_invalid.to_a,
        stuck_unavailable: stuck_unavailable.to_a
      ).daily_report.deliver_now
    end

    ids_to_mark = newly_invalid_ids + stuck_unavailable_ids + consumed_ids
    CustomerVatVerification.where(id: ids_to_mark).update_all(notified_at: Time.current) if ids_to_mark.any?
  end

  private

  # Latest pending verification per active, vat-id-required customer.
  def eligible_latest_verifications
    pending = CustomerVatVerification
                .where(notified_at: nil)
                .joins(:customer).merge(Customer.vat_verification_required)
                .includes(:customer)

    # Only consider rows that are actually the customer's latest verification.
    # If a later non-pending row exists (e.g. recovery already processed), the
    # pending row is stale — skip it. The "always mark consumed" rule keeps
    # such stragglers from accumulating in the partial index.
    pending.select do |v|
      latest_id = CustomerVatVerification
                    .where(customer_id: v.customer_id)
                    .order(created_at: :desc, id: :desc)
                    .limit(1)
                    .pick(:id)
      v.id == latest_id
    end
  end

  def classify(latest, newly_invalid_ids, stuck_unavailable_ids, consumed_ids)
    case latest.valid_response
    when true
      # Recovery — never reported, but consume to keep the index small.
      consumed_ids << latest.id
    when false
      prior = prior_verification(latest)
      if prior&.valid_response == false
        consumed_ids << latest.id
      else
        newly_invalid_ids << latest.id
      end
    when nil
      most_recent_invalid_or_valid = most_recent_non_nil(latest.customer_id)
      # If the customer's most recent non-nil verification was invalid, they
      # were (or will be) reported via the newly-invalid path. Suppress the
      # stuck-unavailable alert to avoid double-reporting the same trouble.
      if most_recent_invalid_or_valid&.invalid_per_vies?
        consumed_ids << latest.id
        return
      end

      streak_start = current_nil_streak_start(latest, most_recent_invalid_or_valid)
      return if streak_start.created_at > STUCK_UNAVAILABLE_DAYS.days.ago

      already_notified_in_streak = CustomerVatVerification
                                     .where(customer_id: latest.customer_id)
                                     .where("created_at >= ?", streak_start.created_at)
                                     .where(valid_response: nil)
                                     .where.not(notified_at: nil)
                                     .exists?
      if already_notified_in_streak
        consumed_ids << latest.id
      else
        stuck_unavailable_ids << latest.id
      end
    end
  end

  def prior_verification(verification)
    CustomerVatVerification
      .where(customer_id: verification.customer_id)
      .where("created_at < ?", verification.created_at)
      .order(created_at: :desc, id: :desc)
      .first
  end

  def most_recent_non_nil(customer_id)
    CustomerVatVerification
      .where(customer_id: customer_id)
      .where.not(valid_response: nil)
      .order(created_at: :desc, id: :desc)
      .first
  end

  # Earliest verification in the current run of nil results (going back from
  # `latest` to just after the most recent non-nil verification, or to the
  # earliest verification if no non-nil priors exist).
  def current_nil_streak_start(latest, most_recent_non_nil)
    streak = CustomerVatVerification
               .where(customer_id: latest.customer_id)
               .where(valid_response: nil)
    streak = streak.where("created_at > ?", most_recent_non_nil.created_at) if most_recent_non_nil
    streak.order(:created_at, :id).first
  end
end
