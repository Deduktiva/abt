require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "requires name" do
    team = Team.new
    refute team.valid?
    assert_includes team.errors[:name], "can't be blank"
  end

  test "name must be unique (case-insensitive)" do
    Team.create!(name: "UniqueOne")
    dup = Team.new(name: "uniqueone")
    refute dup.valid?
  end

  test "built-in team cannot be destroyed" do
    default = teams(:default)
    refute default.destroy
    assert_includes default.errors[:base], "Cannot delete a built-in team"
    assert Team.exists?(default.id)
  end

  test "team in use by a customer cannot be destroyed" do
    team = Team.create!(name: "Disposable")
    Customer.create!(
      matchcode: "INUSE",
      name: "In Use Co.",
      vat_id: "EU999999999",

      country_iso2: "NL",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: team
    )
    refute team.destroy
    assert_includes team.errors[:base], "Cannot delete a team that owns customers or projects"
  end

  test "team with no customers/projects can be destroyed" do
    team = Team.create!(name: "Empty")
    assert team.destroy
  end

  test "Team.default resolves by the default flag and survives a rename" do
    default = teams(:default)
    assert_equal default, Team.default

    default.update!(name: "Headquarters")
    assert_equal default, Team.default, "Team.default must not depend on the literal name"
  end

  test "renaming the Default team does not break new-user join" do
    teams(:default).update!(name: "Headquarters")
    new_user = User.create!(username: "joiner-rn", full_name: "Joiner", webauthn_id: "joiner-rn-id")
    assert_includes new_user.teams, teams(:default).reload
  end

  test "only one team can carry default: true" do
    other = Team.create!(name: "Other")
    err = assert_raises(ActiveRecord::RecordNotUnique) { other.update!(default: true) }
    assert_match(/default/i, err.message)
  end
end
