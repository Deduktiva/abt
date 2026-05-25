module YearFilterable
  extend ActiveSupport::Concern

  class_methods do
    # Records whose `date` is in the given year. When `include_drafts` is true,
    # records with a null `date` (drafts) are also included.
    def in_year(year, include_drafts: false)
      range = Date.new(year).all_year
      if include_drafts
        where("date BETWEEN ? AND ? OR date IS NULL", range.begin, range.end)
      else
        where(date: range)
      end
    end

    # Distinct years for which records with a `date` exist, newest first.
    # Honors the current scope — callers chain visible_to(user) so the year
    # chips don't leak years from teams the user can't see.
    def available_years
      where.not(date: nil).pluck(:date).map(&:year).uniq.sort.reverse
    end
  end
end
