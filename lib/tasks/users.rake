namespace :users do
  desc "Create an invite and print its URL"
  task invite: :environment do
    invite = UserInvite.create!(created_by_user: nil, note: "bootstrap/cli")
    host = ENV.fetch("APP_HOST", "http://localhost:3000")
    puts "#{host}/invites/#{invite.token}"
    AuditEvent.record!(event_type: "invite_created", subject: nil, actor: nil,
                       metadata: { invite_id: invite.id, via: "rake" })
  end
end
