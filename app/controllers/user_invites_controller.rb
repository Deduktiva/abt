class UserInvitesController < ApplicationController
  def index
    @invites = UserInvite.where(purpose: UserInvite::PURPOSE_SIGNUP)
                         .order(created_at: :desc).limit(50)
  end

  def new
  end

  def create
    invite, plaintext = UserInvite.create_signup!(actor: current_user)
    UserAuditEvent.record!(action: 'invite_created', user: nil, actor: current_user,
                            request: request,
                            metadata: { purpose: 'signup', source: 'web' })

    @invite_url = invite_url(token: plaintext, host: Settings.app.host, protocol: Settings.app.protocol,
                              script_name: Settings.app.script_name)
    @invite = invite
    render :show_invite
  end
end
