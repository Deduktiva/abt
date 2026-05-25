require "test_helper"

class AuthorizationAuditTest < ActionDispatch::IntegrationTest
  test "updating a user's groups writes a groups_updated audit event" do
    bob = users(:bob)
    assert_difference -> { UserAuditEvent.where(action: "groups_updated").count }, 1 do
      patch update_groups_user_path(bob), params: { group_ids: [ groups(:sales).id ] }
    end
    event = UserAuditEvent.where(action: "groups_updated").last
    assert_equal users(:alice), event.actor
    assert_equal bob, event.user
    assert_includes event.metadata["added"], "Sales"
  end

  test "updating a user's teams writes a teams_updated audit event" do
    bob = users(:bob)
    bob.team_memberships.where(team_id: teams(:acme).id).destroy_all
    assert_difference -> { UserAuditEvent.where(action: "teams_updated").count }, 1 do
      patch update_teams_user_path(bob), params: { team_ids: [ teams(:acme).id ] }
    end
    event = UserAuditEvent.where(action: "teams_updated").last
    assert_includes event.metadata["added"], "Acme"
  end

  test "group_created and group_deleted are audited" do
    assert_difference -> { UserAuditEvent.where(action: "group_created").count }, 1 do
      post groups_path, params: { group: { name: "Auditors", description: "audit me",
                                            permission_keys: %w[customers.view],
                                            user_ids: [] } }
    end
    new_group = Group.find_by(name: "Auditors")
    assert_difference -> { UserAuditEvent.where(action: "group_deleted").count }, 1 do
      delete group_path(new_group)
    end
  end

  test "team_created and team_deleted are audited" do
    assert_difference -> { UserAuditEvent.where(action: "team_created").count }, 1 do
      post teams_path, params: { team: { name: "EMEA", description: "eu", user_ids: [] } }
    end
    new_team = Team.find_by(name: "EMEA")
    assert_difference -> { UserAuditEvent.where(action: "team_deleted").count }, 1 do
      delete team_path(new_team)
    end
  end
end
