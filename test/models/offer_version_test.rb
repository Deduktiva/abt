require "test_helper"

class OfferVersionTest < ActiveSupport::TestCase
  def offer
    @offer ||= Offer.create!(
      matchcode: "ver-test",
      customer: customers(:good_eu),
      state: "draft"
    )
  end

  test "assign_version_number defaults to 1 for the first version" do
    version = offer.offer_versions.create!
    assert_equal 1, version.version_number
  end

  test "assign_version_number monotonically increments" do
    offer.offer_versions.create!
    offer.offer_versions.create!
    offer.offer_versions.create!
    assert_equal [ 1, 2, 3 ], offer.offer_versions.order(:version_number).pluck(:version_number)
  end

  test "explicit version_number is honored on create" do
    version = offer.offer_versions.create!(version_number: 5)
    assert_equal 5, version.version_number
  end

  test "version_number unique per offer" do
    offer.offer_versions.create!(version_number: 1)
    duplicate = offer.offer_versions.build(version_number: 1)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:version_number], "has already been taken"
  end

  test "assign_default_tax_class picks the is_default SalesTaxProductClass" do
    default_class = sales_tax_product_classes(:standard)
    assert default_class.is_default?, "fixture precondition failed"
    version = offer.offer_versions.create!
    assert_equal default_class, version.sales_tax_product_class
  end

  test "explicit tax class is honored on create over the is_default fallback" do
    # Create a second product class so we can choose a non-default one.
    klass = SalesTaxProductClass.create!(name: "Reduced", indicator_code: "RED")
    version = offer.offer_versions.create!(sales_tax_product_class: klass)
    assert_equal klass, version.sales_tax_product_class
  end

  test "editable? is only true for draft versions" do
    version = offer.offer_versions.create!(state: "draft")
    assert version.editable?
    version.update!(state: "sent")
    assert_not version.editable?
    version.update!(state: "superseded")
    assert_not version.editable?
  end

  test "identifier uses DRAFT when offer has no document_number yet" do
    version = offer.offer_versions.create!
    assert_equal "DRAFT ver-test v1", version.identifier
  end

  test "identifier uses document_number once assigned" do
    offer.update!(document_number: "20260042")
    version = offer.offer_versions.create!
    assert_equal "20260042 ver-test v1", version.identifier
  end

  test "destroying a version cascades to milestones" do
    version = offer.offer_versions.create!
    milestone = version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 100)
    version.destroy
    assert_nil OfferMilestone.find_by(id: milestone.id)
  end
end
