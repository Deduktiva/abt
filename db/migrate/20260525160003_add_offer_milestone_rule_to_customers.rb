class AddOfferMilestoneRuleToCustomers < ActiveRecord::Migration[8.0]
  def change
    change_table :customers, bulk: true do |t|
      # Total amount at which to split a scaffolded offer from one milestone
      # ("final delivery") into two ("order entry" + "final delivery").
      # NULL ⇒ no rule; admin builds milestones manually.
      t.decimal :offer_milestone_split_threshold, precision: 12, scale: 2
      # Fraction (0..1) of the total assigned to the order-entry milestone
      # when total > threshold. Typical: 0.5.
      t.decimal :offer_milestone_split_first_ratio, precision: 5, scale: 4
    end
  end
end
