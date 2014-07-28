class IssuerCompany
  attr_reader :name, :address, :vat_id

  def initialize(name, address, vat_id)
    @name = name
    @address = address
    @vat_id = vat_id
  end

  def self.from_config
    IssuerCompany.new(Settings.company.name.strip, Settings.company.address.strip, Settings.company.vat_id.strip)
  end
end