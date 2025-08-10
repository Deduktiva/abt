require "test_helper"

class PeriodicJobsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get periodic_jobs_path
    assert_response :success
  end

  test "should get show" do
    job = PeriodicJob.create!(
      name: 'Test Job',
      class_name: 'SamplePeriodicJob',
      schedule: '30m',
      enabled: true
    )
    get periodic_job_path(job)
    assert_response :success
  end

  test "should run job" do
    job = PeriodicJob.create!(
      name: 'Test Job',
      class_name: 'SamplePeriodicJob',
      schedule: '30m',
      enabled: true
    )
    post run_periodic_job_path(job)
    assert_redirected_to job
  end
end
