module PublishableDocument
  extend ActiveSupport::Concern

  class_methods do
    # Configure the instance variable and document label used by the guards.
    #
    #   publishable_document :invoice, label: 'invoice'
    #
    # Generates `require_unpublished` and `require_published` before_action
    # callbacks; controllers declare which actions they guard via
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
