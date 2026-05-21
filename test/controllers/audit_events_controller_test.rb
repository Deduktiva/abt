require 'test_helper'

class AuditEventsControllerTest < ActionDispatch::IntegrationTest
  test "index lists events" do
    get audit_events_url
    assert_response :success
    assert_select 'h1', text: /Audit log/
  end

  test "filters by user_id" do
    get audit_events_url(user_id: users(:alice).id)
    assert_response :success
  end

  test "filters by event_type" do
    AuditEvent.record!(event_type: "login", subject: users(:alice), actor: users(:alice))
    get audit_events_url(event_type: "login")
    assert_response :success
    assert_select 'td', text: 'login'
  end
end
