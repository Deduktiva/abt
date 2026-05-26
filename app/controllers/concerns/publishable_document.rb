module PublishableDocument
  extend ActiveSupport::Concern

  # Invoice and DeliveryNote both include this concern but the actual
  # publish work is intentionally not shared:
  #
  #   - Invoice goes through the InvoicePublisher service which refreshes
  #     the customer snapshot, validates via Invoice#publish_problems,
  #     assigns a document number, mints a public-share token, renders a
  #     PDF, and attaches it. Publishing is irreversible — there is no
  #     unpublish route.
  #   - DeliveryNote#publish! is a short model method (assign date,
  #     document number, set published=true) and an unpublish action
  #     exists to revert it.
  #
  # Both expose a publish_problems method returning user-facing strings,
  # so controllers can share the "check problems → publish → redirect"
  # shape even though the underlying mechanisms differ. publish_problems
  # is the canonical pre-check for the publish action — the model-level
  # must_have_item_line_for_publish validation remains as a save-time
  # safety net for programmatic callers (console, seeds, future code).
  class_methods do
    # Configure the instance variable and document label used by the guards.
    #
    #   publishable_document :invoice, label: 'invoice'
    #
    # Provides require_unpublished and require_published filters; controllers
    # declare which actions they guard via
    #   before_action :require_unpublished, only: [...]
    def publishable_document(ivar_name, label:)
      @publishable_ivar = "@#{ivar_name}"
      @publishable_label = label
    end

    attr_reader :publishable_ivar, :publishable_label
  end

  protected

  def require_unpublished
    if publishable_record.published?
      flash[:error] = "Published #{self.class.publishable_label.pluralize} can not be modified."
      redirect_to publishable_record
      false
    else
      true
    end
  end

  def require_published
    unless publishable_record.published?
      flash[:error] = "Draft #{self.class.publishable_label.pluralize} can not be used for this action."
      redirect_to publishable_record
      false
    else
      true
    end
  end

  private

  def publishable_record
    instance_variable_get(self.class.publishable_ivar)
  end
end
