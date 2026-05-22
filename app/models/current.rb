class Current < ActiveSupport::CurrentAttributes
  attribute :user, :session, :request_ip, :user_agent
end
