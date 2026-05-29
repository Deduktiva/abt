# Index actions that back a searchable dropdown (matchcode-named, active-flagged
# resources like Customer and Project). Shares the active/inactive/all filter and
# the HTML-or-dropdown-options response shape.
module SearchableDropdownIndex
  extend ActiveSupport::Concern

  private

  # Filter a base relation by params[:filter], defaulting to active records.
  # Assigns params[:filter] so the view reflects the effective filter.
  def filtered_by_active(scope)
    params[:filter] ||= "active"
    case params[:filter]
    when "all"
      scope
    when "inactive"
      scope.where(active: false)
    else
      scope.where(active: true)
    end
  end

  # Index pages render a normal HTML page, plus a turbo_stream of <option>s for
  # the searchable_dropdown Stimulus controller's XHR fetch. That controller sets
  # X-Requested-With; the xhr guard keeps Turbo navigation (whose Accept also
  # lists turbo_stream) from rendering options into a missing target on
  # post-delete redirects.
  def respond_to_index_or_dropdown
    respond_to do |format|
      format.html
      format.turbo_stream { render :filter_options } if request.xhr?
    end
  end
end
