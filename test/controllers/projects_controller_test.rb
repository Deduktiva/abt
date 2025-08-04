require 'test_helper'

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @project = projects(:one)
    @customer = customers(:good_eu)
  end

  test "should get index" do
    get projects_url
    assert_response :success
    assert_select 'table tr', count: Project.count + 1 # +1 for header row
  end

  test "should filter active projects" do
    # Create an inactive project
    inactive_project = Project.create!(
      matchcode: 'INACTIVE',
      description: 'Inactive project',
      bill_to_customer: @customer,
      active: false
    )

    get projects_url(active: true)
    assert_response :success
    # Should not include inactive project
    assert_select 'table tr', count: Project.active.count + 1
  end

  test "should filter inactive projects" do
    # Create an inactive project
    inactive_project = Project.create!(
      matchcode: 'INACTIVE',
      description: 'Inactive project',
      bill_to_customer: @customer,
      active: false
    )

    get projects_url(active: false)
    assert_response :success
    # Should only include inactive projects
    assert_select 'table tr', count: Project.inactive.count + 1
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
          time_budget: '40 hours',
          active: true
        }
      }
    end

    assert_redirected_to project_url(Project.last)
    assert Project.last.active?
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

  test "index shows 'Used' text instead of delete link for used projects" do
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
    # Should show 'Used' text instead of delete link
    assert_select 'span.text-muted.small', text: 'Used'
    # Should NOT have delete link for used project
    assert_select "a[href='#{project_path(used_project)}'][data-turbo-method='delete']", count: 0
  end

  test "project form includes active checkbox" do
    get edit_project_url(@project)
    assert_response :success
    assert_select 'input[type="checkbox"][name="project[active]"]'
    assert_select 'label.form-check-label', text: 'Active'
  end

  test "index shows status filter buttons" do
    get projects_url
    assert_response :success
    assert_select 'a.page-link', text: 'All'
    assert_select 'a.page-link', text: 'Active'
    assert_select 'a.page-link', text: 'Inactive'
  end
end