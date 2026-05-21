require 'test_helper'

class UserInvitesControllerTest < ActionDispatch::IntegrationTest
  test "index lists invites and shows new-invite form" do
    get user_invites_url
    assert_response :success
    assert_select 'form'
  end

  test "create makes a pending invite owned by current user" do
    assert_difference("UserInvite.count", +1) do
      post user_invites_url, params: { user_invite: { note: "for someone" } }
    end
    invite = UserInvite.order(:created_at).last
    assert_equal users(:alice), invite.created_by_user
    assert_equal "for someone", invite.note
    assert invite.consumable?
    assert AuditEvent.where(event_type: "invite_created", actor_user: users(:alice)).exists?
  end

  test "destroy expires a pending invite" do
    invite = user_invites(:pending)
    assert invite.consumable?
    assert_difference("AuditEvent.where(event_type: 'invite_revoked').count", +1) do
      delete user_invite_url(invite)
    end
    invite.reload
    refute invite.consumable?
  end

  test "destroy refuses a consumed invite" do
    invite = user_invites(:consumed)
    delete user_invite_url(invite)
    assert_redirected_to user_invites_path
    follow_redirect!
    assert_select '.alert-danger', text: /Cannot revoke a consumed invite/
  end
end
