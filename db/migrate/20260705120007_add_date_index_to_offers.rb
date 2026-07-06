class AddDateIndexToOffers < ActiveRecord::Migration[8.1]
  def change
    add_index :offers, :date
  end
end
