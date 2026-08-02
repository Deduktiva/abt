class RenameIssuerCompaniesToBusinesses < ActiveRecord::Migration[8.1]
  PERMISSION_KEYS = {
    "issuer_company.view" => "business.view",
    "issuer_company.edit" => "business.edit"
  }.freeze

  def up
    rename_table :issuer_companies, :businesses
    PERMISSION_KEYS.each do |old_key, new_key|
      execute "UPDATE group_permissions SET permission = #{connection.quote(new_key)} WHERE permission = #{connection.quote(old_key)}"
    end
  end

  def down
    rename_table :businesses, :issuer_companies
    PERMISSION_KEYS.each do |old_key, new_key|
      execute "UPDATE group_permissions SET permission = #{connection.quote(old_key)} WHERE permission = #{connection.quote(new_key)}"
    end
  end
end
