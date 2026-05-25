class ReplaceOfferMilestoneRatioWithTemplates < ActiveRecord::Migration[8.0]
  # The first iteration of the milestone-split rule was a two-column shape
  # (threshold + single first-milestone ratio) that hard-coded one or two
  # milestones with English titles. Replace it with two free-form text
  # template lists so admins can configure any number of milestones with
  # their own titles.
  def change
    change_table :customers, bulk: true do |t|
      t.remove :offer_milestone_split_first_ratio, type: :decimal, precision: 5, scale: 4
      # One milestone per line: "Title|trigger|ratio".
      #   trigger is one of: on_order, on_acceptance, on_date.
      #   ratios within a list should sum to 1.0; the last row absorbs the
      #   rounding remainder so the scaffolded amounts add up to the total.
      # Blank lines and surrounding whitespace are ignored.
      t.text :offer_milestone_templates_below
      t.text :offer_milestone_templates_above
    end
  end
end
