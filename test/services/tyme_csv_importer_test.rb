require "test_helper"

class TymeCsvImporterTest < ActiveSupport::TestCase
  def csv
    file_fixture("tyme_sample.csv").read
  end

  def import(customer: customers(:good_eu))
    TymeCsvImporter.new(csv, customer: customer).lines
  end

  test "produces one line per task and month" do
    titles = import.map { |l| l[:title] }
    assert_equal [
      "IT Consulting per hour: Project Alpha",
      "IT Consulting per hour: Public Website",
      "IT Consulting per hour: Project Alpha"
    ], titles
  end

  test "sums durations into decimal hours as quantity" do
    assert_equal [ "1.25", "0.5", "6.75" ], import.map { |l| l[:quantity] }
  end

  test "carries the rate from the CSV" do
    assert_equal [ "120", "120", "120" ], import.map { |l| l[:rate] }
  end

  test "itemizes each entry as date and duration without clock times" do
    description = import.last[:description]
    assert_includes description, "02.04.2025 45m Finish installation on host-01"
    assert_includes description, "07.04.2025 1h Setup fail2ban; fix existing rules"
    refute_includes description, "09:52"
    refute_includes description, "13:03"
  end

  test "flattens multi-line notes into a single semicolon-separated row" do
    assert_includes import.first[:description],
      "25.03.2025 1h15m API + collector maintenance; API fix CI pipeline after linter update; collector fix bugs identified by review"
  end

  test "renders title and month header in an English customer's locale" do
    line = import(customer: customers(:good_eu)).first
    assert_equal "IT Consulting per hour: Project Alpha", line[:title]
    assert_includes line[:description], "March 2025"
  end

  test "renders title and month header in a German customer's locale" do
    line = import(customer: customers(:good_national)).first
    assert_equal "IT-Beratung pro Stunde: Project Alpha", line[:title]
    assert_includes line[:description], "März 2025"
  end

  test "includes the end-customer line when the project differs from the customer" do
    assert_includes import(customer: customers(:good_eu)).first[:description],
      "End client: Northwind Ltd"
  end

  test "omits the end-customer line when the project matches the customer name" do
    customer = customers(:good_eu)
    customer.name = "Northwind Ltd"
    refute_includes TymeCsvImporter.new(csv, customer: customer).lines.first[:description],
      "Northwind Ltd"
  end

  test "omits the end-customer line when the project matches the customer matchcode" do
    customer = customers(:good_eu)
    customer.matchcode = "Northwind Ltd GmbH"
    refute_includes TymeCsvImporter.new(csv, customer: customer).lines.first[:description],
      "End client:"
  end

  test "groups by the tracked local date regardless of the application time zone" do
    csv = "project;task;start;duration;rate;note\nClient;Boundary;2025-05-01T00:30:00+02:00;60;100;Late night\n"
    Time.use_zone("Pacific/Honolulu") do
      description = TymeCsvImporter.new(csv, customer: customers(:good_eu)).lines.first[:description]
      assert_includes description, "May 2025"
      assert_includes description, "01.05.2025"
    end
  end

  test "uses the Austrian spelling Jänner for January in German" do
    csv = "project;task;start;duration;rate;note\nClient;Jan;2025-01-15T10:00:00+01:00;60;100;Work\n"
    description = TymeCsvImporter.new(csv, customer: customers(:good_national)).lines.first[:description]
    assert_includes description, "Jänner 2025"
  end

  test "raises on empty input" do
    assert_raises(ArgumentError) { TymeCsvImporter.new("", customer: customers(:good_eu)).lines }
  end

  test "raises when a required column is missing" do
    headerless = "type;project;task\ntimed;X;Y\n"
    assert_raises(ArgumentError) { TymeCsvImporter.new(headerless, customer: customers(:good_eu)).lines }
  end
end
