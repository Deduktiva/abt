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

    @invite_url = AbsoluteUrl.invite(plaintext)
    @invite = invite
    render :show_invite
  end
end
