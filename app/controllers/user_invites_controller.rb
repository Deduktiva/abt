class UserInvitesController < ApplicationController
  def index
    @invites = UserInvite.order(created_at: :desc).limit(100)
    @new_invite = UserInvite.new
  end

  def create
    @invite = UserInvite.create!(created_by_user: current_user, note: params.dig(:user_invite, :note).presence)
    AuditEvent.record!(event_type: "invite_created", subject: nil, actor: current_user, request: request,
                       metadata: { invite_id: @invite.id, note: @invite.note })
    redirect_to user_invites_path, notice: "Invite created."
  end

  def destroy
    @invite = UserInvite.find(params[:id])
    if @invite.consumed?
      redirect_to user_invites_path, alert: "Cannot revoke a consumed invite." and return
    end
    @invite.update!(expires_at: Time.current)
    AuditEvent.record!(event_type: "invite_revoked", subject: nil, actor: current_user, request: request,
                       metadata: { invite_id: @invite.id })
    redirect_to user_invites_path, notice: "Invite revoked."
  end
end
