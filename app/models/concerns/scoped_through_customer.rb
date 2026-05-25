module ScopedThroughCustomer
  extend ActiveSupport::Concern

  # Invoices and delivery notes inherit team visibility from their
  # customer (they have no team_id of their own). Without this concern a
  # user with invoices.edit / delivery_notes.edit in team A could mass-
  # assign `customer_id` (or `project_id`) referencing another team's
  # records and plant invoices/delivery notes into that team's books.
  #
  # Enforcement mirrors TeamOwned#validate_team_assignment: the check
  # reads Current.user (set by ApplicationController#authenticate on every
  # authenticated request), so a future controller can't "forget" to
  # authorize the assignment. System contexts (seeds, console, jobs)
  # have no Current.user and the check skips.
  included do
    validate :customer_must_be_visible_to_current_user, if: :will_save_change_to_customer_id?
    validate :project_must_be_visible_to_current_user,  if: :will_save_change_to_project_id?
  end

  private

  def customer_must_be_visible_to_current_user
    user = Current.user
    return if user.nil?
    return if customer_id && Customer.visible_to(user).where(id: customer_id).exists?
    errors.add(:customer_id, "must be a customer you can access")
  end

  def project_must_be_visible_to_current_user
    return if project_id.nil?
    user = Current.user
    return if user.nil?
    return if Project.visible_to(user).where(id: project_id).exists?
    errors.add(:project_id, "must be a project you can access")
  end
end
