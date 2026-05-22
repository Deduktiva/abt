namespace :users do
  desc 'Create a signup invite URL for bootstrapping the first user'
  task invite: :environment do
    invite, plaintext = UserInvite.create_signup!(actor: nil)
    UserAuditEvent.record!(
      action: 'invite_created',
      user: nil,
      actor: nil,
      metadata: { purpose: 'signup', source: 'rake' }
    )

    url = Rails.application.routes.url_helpers.invite_url(
      token: plaintext,
      host: Settings.app.host,
      protocol: Settings.app.protocol
    )

    puts ''
    puts 'Invite URL (valid until ' + invite.expires_at.utc.iso8601 + '):'
    puts url
    puts ''
  end
end
