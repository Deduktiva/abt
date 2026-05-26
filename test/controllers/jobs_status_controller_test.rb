require "test_helper"

class JobsStatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    SolidQueue::FailedExecution.delete_all
    SolidQueue::ReadyExecution.delete_all
    SolidQueue::ScheduledExecution.delete_all
    SolidQueue::ClaimedExecution.delete_all
    SolidQueue::BlockedExecution.delete_all
    SolidQueue::RecurringExecution.delete_all
    SolidQueue::Job.delete_all
    SolidQueue::RecurringTask.delete_all
    SolidQueue::Process.delete_all
  end

  test "renders an empty status page" do
    get jobs_status_path
    assert_response :success
    assert_select ".breadcrumb-item.active", text: "Background Jobs"
    assert_select ".card-header", text: "Worker Processes"
    assert_select ".card-header", text: "Recurring Tasks"
    assert_select ".card-header", text: "Recently Failed Jobs"
    assert_select ".card-header", text: "Recently Finished Jobs"
    assert_select "p.text-danger", text: /No worker processes registered/
  end

  test "renders worker process rows with alive and stale badges" do
    SolidQueue::Process.create!(
      kind: "Worker", name: "worker-fresh", hostname: "h1", pid: 1,
      last_heartbeat_at: 10.seconds.ago
    )
    SolidQueue::Process.create!(
      kind: "Worker", name: "worker-stale", hostname: "h2", pid: 2,
      last_heartbeat_at: 5.minutes.ago
    )

    get jobs_status_path
    assert_response :success
    assert_select "td", text: "worker-fresh"
    assert_select "td", text: "worker-stale"
    assert_select ".badge.bg-success", text: "Alive"
    assert_select ".badge.bg-danger", text: "Stale"
  end

  test "shows recurring tasks with class and command entries" do
    SolidQueue::RecurringTask.create!(
      key: "my_class_task", schedule: "0 8 */2 * *",
      class_name: "OverdueInvoicesReportJob", queue_name: "default", static: true
    )
    SolidQueue::RecurringTask.create!(
      key: "my_command_task", schedule: "every hour",
      command: "SolidQueue::Job.clear_finished_in_batches", static: true
    )

    get jobs_status_path
    assert_response :success
    assert_select "code", text: "my_class_task"
    assert_select "code", text: "my_command_task"
    assert_select "td", text: "OverdueInvoicesReportJob"
    assert_select "code", text: "SolidQueue::Job.clear_finished_in_batches"
  end

  test "lists recently failed jobs with error class and message" do
    job = SolidQueue::Job.create!(class_name: "BoomJob", queue_name: "default", arguments: "[]")
    SolidQueue::FailedExecution.create!(
      job: job,
      error: { exception_class: "RuntimeError", message: "kaboom", backtrace: [] }
    )

    get jobs_status_path
    assert_response :success
    assert_select "td", text: "BoomJob"
    assert_select "strong", text: "RuntimeError"
    assert_select "div.small.text-muted", text: /kaboom/
  end
end
