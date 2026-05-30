require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @customer = customers(:good_eu)
  end

  test "should get index" do
    get projects_url(filter: "all")
    assert_response :success
    assert_select "table tr", count: Project.count + 1 # +1 for header row
  end

  test "should filter projects by active status and handle index properly" do
    # Test all filter options in a single request cycle
    [ "active", "inactive", "all" ].each do |filter_type|
      get projects_url(filter: filter_type)
      assert_response :success
      assert_select ".status-filter .active", text: filter_type.capitalize

      case filter_type
      when "active"
        assert_select "td", text: "INACTIVE", count: 0
      when "inactive", "all"
        assert_select "td", text: "INACTIVE"
      end
    end

    # Test default behavior (should default to active)
    get projects_url
    assert_response :success
    assert_select ".status-filter .active", text: "Active"
    assert_select "td", text: "INACTIVE", count: 0
  end

  test "should show project" do
    get project_url(@project)
    assert_response :success
    assert_select ".badge", text: "Inactive", count: 0
  end

  test "should show inactive badge on project page" do
    @project.update!(active: false)
    get project_url(@project)
    assert_response :success
    assert_select ".badge.bg-secondary", text: "Inactive"
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "new project form marks required fields and lets the browser validate them" do
    get new_project_url
    assert_response :success

    assert_select "form#page-form:not([novalidate])"

    assert_select "input#project_matchcode[required]"
    assert_select "select#project_team_id[required]"

    assert_select "label.required[for='project_matchcode']"
    assert_select "label.required[for='project_team_id']"
  end

  test "should create project" do
    assert_difference("Project.count") do
      post projects_url, params: {
        project: {
          matchcode: "NEW_PROJECT",
          description: "New project",
          bill_to_customer_id: @customer.id,
          active: true,
          team_id: @customer.team_id
        }
      }
    end

    assert_redirected_to project_url(Project.last)
    assert Project.last.active?
  end

  test "should create project without customer" do
    assert_difference("Project.count") do
      post projects_url, params: {
        project: {
          matchcode: "NO_CUSTOMER_PROJECT",
          description: "Project without customer for reuse",
          bill_to_customer_id: "", # Empty customer ID
          active: true,
          team_id: teams(:default).id
        }
      }
    end

    assert_redirected_to project_url(Project.last)
    new_project = Project.last
    assert new_project.active?
    assert_nil new_project.bill_to_customer
    assert_equal "NO_CUSTOMER_PROJECT", new_project.matchcode
  end

  test "should get edit" do
    get edit_project_url(@project)
    assert_response :success
  end

  test "should update project" do
    patch project_url(@project), params: {
      project: {
        description: "Updated description",
        active: false
      }
    }
    assert_redirected_to project_url(@project)

    @project.reload
    assert_equal "Updated description", @project.description
    assert_not @project.active?
  end

  test "should delete unused project" do
    # Create a project that's not used in any invoices
    unused_project = Project.create!(
      matchcode: "UNUSED",
      description: "Unused project",
      bill_to_customer: @customer,
      team: teams(:default)
    )

    assert_difference("Project.count", -1) do
      delete project_url(unused_project)
    end

    assert_redirected_to projects_url
    assert_equal "Project was successfully deleted.", flash[:notice]
  end

  test "should not delete project used in invoices" do
    # Create a project and an invoice that uses it
    used_project = Project.create!(
      matchcode: "USED",
      description: "Used project",
      bill_to_customer: @customer,
      team: teams(:default)
    )

    Invoice.create!(
      customer: @customer,
      project: used_project
    )

    assert_no_difference("Project.count") do
      delete project_url(used_project)
    end

    assert_redirected_to projects_url
    assert_includes flash[:alert], "Cannot delete project that has been used in invoices"
  end

  test "index shows delete link for unused projects" do
    # Create a project that's not used in any invoices
    unused_project = Project.create!(
      matchcode: "UNUSED",
      description: "Unused project",
      bill_to_customer: @customer,
      team: teams(:default)
    )

    # Verify it's not used
    assert_not unused_project.used_in_invoices?
    assert unused_project.can_be_deleted?

    get projects_url
    assert_response :success

    # Should have delete link for unused project (use project_path instead of project_url)
    assert_select "a[href='#{project_path(unused_project)}'][data-turbo-method='delete']"
  end

  test "index hides delete link for used projects" do
    # Create a project and an invoice that uses it
    used_project = Project.create!(
      matchcode: "USED",
      description: "Used project",
      bill_to_customer: @customer,
      team: teams(:default)
    )

    Invoice.create!(
      customer: @customer,
      project: used_project
    )

    get projects_url
    assert_response :success
    # Should NOT have delete link for used project
    assert_select "a[href='#{project_path(used_project)}'][data-turbo-method='delete']", count: 0
  end

  test "project form includes active checkbox" do
    get edit_project_url(@project)
    assert_response :success
    assert_select 'input[type="checkbox"][name="project[active]"]'
    assert_select "label.form-check-label", text: "Active"
  end

  test "should show project without customer" do
    # Create a project without a customer
    project_without_customer = Project.create!(
      matchcode: "NO_CUSTOMER",
      description: "Project without customer",
      bill_to_customer: nil,
      active: true,
      team: teams(:default)
    )

    get project_url(project_without_customer)
    assert_response :success
    assert_select "span.text-muted", text: "No customer (reusable project)"
  end

  test "should edit project without customer" do
    # Create a project without a customer
    project_without_customer = Project.create!(
      matchcode: "NO_CUSTOMER",
      description: "Project without customer",
      bill_to_customer: nil,
      active: true,
      team: teams(:default)
    )

    get edit_project_url(project_without_customer)
    assert_response :success
    # Form should render without errors
    assert_select 'select[name="project[bill_to_customer_id]"]'
    assert_select "option", text: "No customer (reusable project)"
  end

  test "should update project to remove customer" do
    # Start with a project that has a customer
    assert_not_nil @project.bill_to_customer

    # Update to remove the customer
    patch project_url(@project), params: {
      project: {
        bill_to_customer_id: "", # Empty to remove customer
        description: "Updated to have no customer"
      }
    }
    assert_redirected_to project_url(@project)

    @project.reload
    assert_nil @project.bill_to_customer
    assert_equal "Updated to have no customer", @project.description
  end

  test "dropdown scopes projects to the customer plus reusable projects" do
    customer = customers(:good_eu)
    other = customers(:good_national)
    mine = Project.create!(matchcode: "MINE", description: "x", bill_to_customer: customer, active: true, team: teams(:default))
    theirs = Project.create!(matchcode: "THEIRS", description: "x", bill_to_customer: other, active: true, team: teams(:default))
    reusable = Project.create!(matchcode: "REUSE", description: "x", bill_to_customer: nil, active: true, team: teams(:default))

    get projects_url(customer_id: customer.id), headers: dropdown_xhr_headers

    assert_select %(turbo-stream[action="update"][target="project-dropdown-menu"]) do
      assert_select ".searchable-option[data-item-id=?]", mine.id.to_s
      assert_select ".searchable-option[data-item-id=?]", reusable.id.to_s
      assert_select ".searchable-option[data-item-id=?]", theirs.id.to_s, count: 0
    end
  end

  private

  # The searchable_dropdown Stimulus controller fetches options as a turbo
  # stream and sets X-Requested-With; the index only renders options for that
  # combination (see ProjectsController#index).
  def dropdown_xhr_headers
    { "Accept" => "text/vnd.turbo-stream.html", "X-Requested-With" => "XMLHttpRequest" }
  end
end
