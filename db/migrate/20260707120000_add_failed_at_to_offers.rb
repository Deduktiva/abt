class AddFailedAtToOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :offers, :failed_at, :datetime
  end
end
