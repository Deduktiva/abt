class OfferMilestoneScaffolder
  class MilestonesPresent < StandardError; end

  Row = Struct.new(:title, :trigger, :percentage)

  def initialize(customer, total)
    @customer = customer
    @total = BigDecimal(total.to_s)
  end

  def apply_to(version)
    raise MilestonesPresent if version.milestones.any?

    rows = parse_rows
    places = IssuerCompany.get_the_issuer!.money_decimal_places
    milestones =
      if rows.empty?
        [ version.milestones.create!(position: 1, title: "Milestone", trigger: "on_acceptance",
                                    amount: @total.round(places)) ]
      else
        amounts = rows[0..-2].map { |r| (@total * r.percentage / 100).round(places) }
        amounts << @total - amounts.sum
        rows.each_with_index.map do |row, i|
          version.milestones.create!(position: i + 1, title: row.title, trigger: row.trigger,
                                     trigger_date: (Date.current if row.trigger == "on_date"),
                                     amount: amounts[i],
                                     skip_delivery_note: row.trigger == "on_order")
        end
      end
    milestones
  end

  private

  # Without a threshold the "below" template always applies.
  def template_source
    threshold = @customer.offer_milestone_split_threshold
    if threshold.present? && @total >= threshold
      @customer.offer_milestone_templates_above
    else
      @customer.offer_milestone_templates_below
    end
  end

  def parse_rows
    template_source.to_s.each_line.filter_map do |line|
      title, trigger, percentage = line.strip.split("|").map(&:strip)
      next if title.blank? || !OfferMilestone::TRIGGERS.include?(trigger)
      percentage = Float(percentage, exception: false)
      next if percentage.nil? || percentage <= 0 || percentage > 100
      Row.new(title, trigger, BigDecimal(percentage.to_s))
    end
  end
end
