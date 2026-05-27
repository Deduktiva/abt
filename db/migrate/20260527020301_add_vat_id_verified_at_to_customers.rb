class AddVatIdVerifiedAtToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :vat_id_verified_at, :datetime
  end
end
