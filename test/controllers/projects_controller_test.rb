require 'test_helper'

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @customer = customers(:good_eu)
  end

  test "should get index" do
    get projects_url(filter: 'all')
    assert_response :success
    assert_select 'table tr', count: Project.count + 1 # +1 for header row
  end

  test "should filter customers by active status" do
    # Create inactive project
    inactive = Project.create!(
      matchcode: 'INACTIVE',
      description: 'Inactive project',
      active: false,
      bill_to_customer: @customer
    )

    # Defaults to active only
    get projects_url
    assert_response :success
    assert_select '.status-filter .active', text: 'Active'
    assert_select 'td', text: 'INACTIVE', count: 0

    # Test showing only active
    get projects_url(filter: 'active')
    assert_response :success
    assert_select '.status-filter .active', text: 'Active'
    assert_select 'td', text: 'INACTIVE', count: 0

    # Test showing only inactive
    get projects_url(filter: 'inactive')
    assert_response :success
    assert_select '.status-filter .active', text: 'Inactive'
    assert_select 'td', text: 'INACTIVE'

    # Test showing all
    get projects_url(filter: 'all')
    assert_response :success
    assert_select '.status-filter .active', text: 'All'
    assert_select 'td', text: 'INACTIVE'
  end

  test "should show project" do
    get project_url(@project)
    assert_response :success
    assert_select 'h5', text: 'Project Information'
  end

  test "should show active status on project page" do
    get project_url(@project)
    assert_response :success
    assert_select '.badge.bg-success', text: 'Active'
  end

  test "should show inactive status on project page" do
    @project.update!(active: false)
    get project_url(@project)
    assert_response :success
    assert_select '.badge.bg-secondary', text: 'Inactive'
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "should create project" do
    assert_difference('Project.count') do
      post projects_url, params: {
        project: {
          matchcode: 'NEW_PROJECT',
          description: 'New project',
          bill_to_customer_id: @customer.id,
          active: true
        }
      }
    end

    assert_redirected_to project_url(Project.last)
    assert Project.last.active?
  end

  test "should create project without customer" do
    assert_difference('Project.count') do
      post projects_url, params: {
        project: {
          matchcode: 'NO_CUSTOMER_PROJECT',
          description: 'Project without customer for reuse',
          bill_to_customer_id: '', # Empty customer ID
          active: true
        }
      }
    end

    assert_redirected_to project_url(Project.last)
    new_project = Project.last
    assert new_project.active?
    assert_nil new_project.bill_to_customer
    assert_equal 'NO_CUSTOMER_PROJECT', new_project.matchcode
  end

  test "should get edit" do
    get edit_project_url(@project)
    assert_response :success
  end

  test "should update project" do
    patch project_url(@project), params: {
      project: {
        description: 'Updated description',
        active: false
      }
    }
    assert_redirected_to project_url(@project)

    @project.reload
    assert_equal 'Updated description', @project.description
    assert_not @project.active?
  end

  test "should delete unused project" do
    # Create a project that's not used in any invoices
    unused_project = Project.create!(
      matchcode: 'UNUSED',
      description: 'Unused project',
      bill_to_customer: @customer
    )

    assert_difference('Project.count', -1) do
      delete project_url(unused_project)
    end

    assert_redirected_to projects_url
    assert_equal 'Project was successfully deleted.', flash[:notice]
  end

  test "should not delete project used in invoices" do
    # Create a project and an invoice that uses it
    used_project = Project.create!(
      matchcode: 'USED',
      description: 'Used project',
      bill_to_customer: @customer
    )

    Invoice.create!(
      customer: @customer,
      project: used_project
    )

    assert_no_difference('Project.count') do
      delete project_url(used_project)
    end

    assert_redirected_to projects_url
    assert_includes flash[:alert], 'Cannot delete project that has been used in invoices'
  end

  test "index shows delete link for unused projects" do
    # Create a project that's not used in any invoices
    unused_project = Project.create!(
      matchcode: 'UNUSED',
      description: 'Unused project',
      bill_to_customer: @customer
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
      matchcode: 'USED',
      description: 'Used project',
      bill_to_customer: @customer
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
    assert_select 'label.form-check-label', text: 'Active'
  end

  test "should show project without customer" do
    # Create a project without a customer
    project_without_customer = Project.create!(
      matchcode: 'NO_CUSTOMER',
      description: 'Project without customer',
      bill_to_customer: nil,
      active: true
    )

    get project_url(project_without_customer)
    assert_response :success
    assert_select 'span.text-muted', text: 'No customer (reusable project)'
  end

  test "should edit project without customer" do
    # Create a project without a customer
    project_without_customer = Project.create!(
      matchcode: 'NO_CUSTOMER',
      description: 'Project without customer',
      bill_to_customer: nil,
      active: true
    )

    get edit_project_url(project_without_customer)
    assert_response :success
    # Form should render without errors
    assert_select 'select[name="project[bill_to_customer_id]"]'
    assert_select 'option', text: 'No customer (reusable project)'
  end

  test "should update project to remove customer" do
    # Start with a project that has a customer
    assert_not_nil @project.bill_to_customer

    # Update to remove the customer
    patch project_url(@project), params: {
      project: {
        bill_to_customer_id: '', # Empty to remove customer
        description: 'Updated to have no customer'
      }
    }
    assert_redirected_to project_url(@project)

    @project.reload
    assert_nil @project.bill_to_customer
    assert_equal 'Updated to have no customer', @project.description
  end

  test "should filter projects by customer_id in JSON format" do
    # Create additional projects for testing
    customer_a = customers(:good_eu)
    customer_b = customers(:good_national)

    project_a = Project.create!(
      matchcode: 'CUST_A',
      description: 'Project for Customer A',
      bill_to_customer: customer_a,
      active: true
    )

    project_b = Project.create!(
      matchcode: 'CUST_B',
      description: 'Project for Customer B',
      bill_to_customer: customer_b,
      active: true
    )

    get projects_url(format: :json, customer_id: customer_a.id)
    assert_response :success

    projects = JSON.parse(response.body)
    customer_a_project_ids = projects.map { |p| p['id'] }

    assert_includes customer_a_project_ids, project_a.id
    assert_not_includes customer_a_project_ids, project_b.id
  end

  test "should include reusable projects when include_reusable is true" do
    # Create a reusable project (no customer)
    reusable_project = Project.create!(
      matchcode: 'REUSABLE',
      description: 'Reusable project',
      bill_to_customer: nil,
      active: true
    )

    get projects_url(format: :json, include_reusable: 'true')
    assert_response :success

    projects = JSON.parse(response.body)
    project_ids = projects.map { |p| p['id'] }
    reusable_flags = projects.map { |p| p['is_reusable'] }

    assert_includes project_ids, reusable_project.id
    assert_includes reusable_flags, true
  end

  test "should filter by customer and include reusable projects" do
    customer = customers(:good_eu)

    # Create project assigned to customer
    customer_project = Project.create!(
      matchcode: 'ASSIGNED',
      description: 'Project assigned to customer',
      bill_to_customer: customer,
      active: true
    )

    # Create reusable project
    reusable_project = Project.create!(
      matchcode: 'REUSABLE',
      description: 'Reusable project',
      bill_to_customer: nil,
      active: true
    )

    # Create project for different customer
    other_customer = customers(:good_national)
    other_project = Project.create!(
      matchcode: 'OTHER',
      description: 'Project for other customer',
      bill_to_customer: other_customer,
      active: true
    )

    get projects_url(format: :json, customer_id: customer.id, include_reusable: 'true')
    assert_response :success

    projects = JSON.parse(response.body)
    project_ids = projects.map { |p| p['id'] }

    # Should include customer's project and reusable project
    assert_includes project_ids, customer_project.id
    assert_includes project_ids, reusable_project.id

    # Should NOT include other customer's project
    assert_not_includes project_ids, other_project.id
  end

  test "JSON response includes all required fields" do
    get projects_url(format: :json, filter: 'active')
    assert_response :success

    projects = JSON.parse(response.body)
    assert projects.length > 0

    project = projects.first
    assert project.key?('id')
    assert project.key?('name')
    assert project.key?('matchcode')
    assert project.key?('description')
    assert project.key?('is_reusable')
  end

  test "JSON response marks reusable projects correctly" do
    # Create projects with and without customers
    with_customer = Project.create!(
      matchcode: 'WITH_CUST',
      description: 'With customer',
      bill_to_customer: customers(:good_eu),
      active: true
    )

    without_customer = Project.create!(
      matchcode: 'NO_CUST',
      description: 'Without customer',
      bill_to_customer: nil,
      active: true
    )

    get projects_url(format: :json, filter: 'active')
    assert_response :success

    projects = JSON.parse(response.body)

    with_cust_data = projects.find { |p| p['id'] == with_customer.id }
    without_cust_data = projects.find { |p| p['id'] == without_customer.id }

    assert_not_nil with_cust_data
    assert_not_nil without_cust_data

    assert_equal false, with_cust_data['is_reusable']
    assert_equal true, without_cust_data['is_reusable']
  end
end
