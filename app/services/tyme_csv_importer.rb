require "csv"
require "time"

# Parses a Tyme time-tracking CSV export into invoice line attributes.
#
# One line is produced per (task, calendar month). The rate comes from the CSV;
# the quantity is the group's summed duration in decimal hours. The description
# itemizes each entry as "<date> <duration> <note>" (no clock times), prefixed by
# a localized month header and an optional "end customer" line when the tracked
# client differs from the invoice's customer. All text is rendered in the
# customer's locale.
class TymeCsvImporter
  REQUIRED_COLUMNS = %w[project task start duration rate note].freeze
  LEGAL_SUFFIXES = /\b(gmbh|ag|ltd|inc|llc|kg|co|corp|b\.?v|e\.?u)\.?\b/

  def initialize(source, customer: nil)
    @source = source.respond_to?(:read) ? source.read : source.to_s
    @customer = customer
  end

  def lines
    locale = @customer&.language&.iso_code.presence || I18n.default_locale
    I18n.with_locale(locale) { build_lines }
  end

  private

  def build_lines
    rows = parse_rows
    grouped = rows.group_by { |r| [ r[:task], r[:date].year, r[:date].month ] }

    grouped
      .sort_by { |(task, year, month), _| [ year, month, task ] }
      .map { |(task, _year, _month), entries| build_line(task, entries) }
  end

  def parse_rows
    table = CSV.parse(@source, col_sep: ";", headers: true, quote_char: '"')
    raise ArgumentError, "CSV has no data rows" if table.headers.compact.empty? || table.empty?

    missing = REQUIRED_COLUMNS - table.headers
    raise ArgumentError, "CSV is missing columns: #{missing.join(', ')}" if missing.any?

    table.map do |row|
      {
        client: row["project"],
        task: row["task"],
        date: Time.parse(row["start"]).to_date,
        minutes: row["duration"].to_i,
        rate: row["rate"],
        note: row["note"]
      }
    end
  rescue CSV::MalformedCSVError => e
    raise ArgumentError, "CSV could not be parsed: #{e.message}"
  end

  def build_line(task, entries)
    client = entries.first[:client]
    date = entries.first[:date]
    total_minutes = entries.sum { |e| e[:minutes] }

    {
      title: I18n.t("invoices.import.line_title", project: task),
      description: description(client, date, entries),
      rate: entries.first[:rate],
      quantity: format_quantity(total_minutes)
    }
  end

  def description(client, date, entries)
    rows = []
    rows << I18n.t("invoices.import.end_customer", client: client) unless matches_customer?(client)
    rows << month_header(date)
    entries.each do |e|
      rows << "#{I18n.l(e[:date])} #{format_duration(e[:minutes])} #{flatten_note(e[:note])}".strip
    end
    rows.join("\n")
  end

  def month_header(date)
    I18n.t("invoices.import.month_year", month: I18n.t("date.month_names")[date.month], year: date.year)
  end

  def format_quantity(minutes)
    format("%.4f", minutes / 60.0).sub(/\.?0+\z/, "")
  end

  def format_duration(minutes)
    hours, mins = minutes.divmod(60)
    parts = []
    parts << "#{hours}h" if hours.positive?
    parts << "#{mins}m" if mins.positive?
    parts.empty? ? "0m" : parts.join
  end

  def flatten_note(raw)
    raw.to_s.split(/\r?\n/).map { |line| line.strip.sub(/;+\s*\z/, "") }.reject(&:blank?).join("; ")
  end

  def matches_customer?(client)
    return false if @customer.nil?

    [ @customer.name, @customer.matchcode ].any? { |candidate| roughly_equal?(client, candidate) }
  end

  def roughly_equal?(a, b)
    na = normalize(a)
    nb = normalize(b)
    return false if na.blank? || nb.blank?

    na.include?(nb) || nb.include?(na)
  end

  def normalize(value)
    value.to_s.downcase.gsub(LEGAL_SUFFIXES, "").gsub(/[[:space:]]+/, " ").strip
  end
end
