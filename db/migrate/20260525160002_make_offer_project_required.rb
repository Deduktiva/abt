class MakeOfferProjectRequired < ActiveRecord::Migration[8.0]
  def change
    change_column_null :offers, :project_id, false
  end
end
