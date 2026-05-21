class InvitesController < ApplicationController
  skip_before_action :require_login, only: [:show, :accept]

  before_action :load_invite

  def show
    @pending_auth = session[:pending_auth]
    # Stash the invite token in the session so the OmniAuth callback knows
    # this is an invite-driven signup. Only set it while the invite is still
    # usable; expired/consumed invites should not arm the callback.
    session[:pending_invite_token] = @invite.token if @invite.consumable?
  end

  def accept
    unless @invite.consumable?
      redirect_to invite_path(@invite.token), alert: "This invite link is no longer valid." and return
    end

    pending = session[:pending_auth]
    unless pending.present?
      redirect_to invite_path(@invite.token), alert: "Please complete GitHub sign-in first." and return
    end

    username = params[:username].to_s.strip.downcase
    full_name = params[:full_name].to_s.strip

    user = nil
    User.transaction do
      user = User.create!(username: username, full_name: full_name)
      identity = UserIdentity.create!(
        user: user,
        provider: pending["provider"],
        uid: pending["uid"],
        nickname: pending["nickname"],
        email: pending["email"],
        raw_info: pending["raw_info"] || {}
      )
      @invite.consume!(user: user)

      AuditEvent.record!(event_type: "user_created", subject: user, actor: user, request: request,
                         metadata: { username: user.username })
      AuditEvent.record!(event_type: "identity_added", subject: user, actor: user, request: request,
                         metadata: { provider: identity.provider, uid: identity.uid, nickname: identity.nickname })
      AuditEvent.record!(event_type: "invite_consumed", subject: user, actor: user, request: request,
                         metadata: { invite_id: @invite.id })
    end

    session.delete(:pending_auth)
    session.delete(:pending_invite_token)

    start_user_session!(user)
    AuditEvent.record!(event_type: "login", subject: user, actor: user, request: request,
                       metadata: { provider: pending["provider"] })

    redirect_to root_path, notice: "Welcome, #{user.username}!"
  rescue ActiveRecord::RecordInvalid => e
    @pending_auth = session[:pending_auth]
    @errors = e.record.errors.full_messages
    @username = username
    @full_name = full_name
    render :show, status: :unprocessable_content
  end

  private

  def load_invite
    @invite = UserInvite.find_by(token: params[:token])
    unless @invite
      render :not_found, status: :not_found
    end
  end
end
