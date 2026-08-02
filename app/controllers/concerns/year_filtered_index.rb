# Index actions filtered by params[:year] (Invoice, DeliveryNote, Offer). Shares
# the parse and the draft-inclusion rule so the three stay in step.
module YearFilteredIndex
  extend ActiveSupport::Concern

  # Anything outside this falls back to the current year. Unbounded years reach
  # the database as a date range and overflow Postgres' `date` type (4713 BC to
  # 5874897 AD), which raises StatementInvalid instead of rendering the page.
  SELECTABLE_YEARS = 1900..2100

  private

  # Narrow a base relation by params[:year] and assign @selected_year for the
  # view. Drafts have no date and belong under the current year.
  def filtered_by_year(scope)
    @selected_year = selected_year
    return scope if @selected_year == "all"

    scope.in_year(@selected_year, include_drafts: @selected_year == Date.current.year)
  end

  # "all", or a year within SELECTABLE_YEARS. Blank, non-numeric, out-of-range
  # and non-scalar params (?year[]=) all fall back to the current year.
  def selected_year
    raw = params[:year]
    return "all" if raw == "all"

    year = Integer(raw, exception: false) if raw.is_a?(String)
    SELECTABLE_YEARS.cover?(year) ? year : Date.current.year
  end
end
