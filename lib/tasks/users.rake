namespace :users do
  desc "Create a signup invite URL. If no users exist yet, the new signup will be auto-promoted to the Admin group."
  task invite: :environment do
    invite, plaintext = UserInvite.create_signup!(actor: nil)
    UserAuditEvent.record!(
      action: "invite_created",
      user: nil,
      actor: nil,
      metadata: { purpose: "signup", source: "rake" }
    )

    url = AbsoluteUrl.invite(plaintext)

    puts ""
    puts "Invite URL (valid until " + invite.expires_at.utc.iso8601 + "):"
    puts url
    if User.count.zero?
      puts ""
      puts "NOTE: No users exist yet. The first user to sign up will be auto-promoted to the Admin group."
    end
    puts ""
  end
end
