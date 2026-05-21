OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true

Rails.application.config.middleware.use OmniAuth::Builder do
  gh = (Rails.application.credentials.github || {}).to_h.with_indifferent_access
  provider :github, gh[:client_id], gh[:client_secret], scope: "read:user user:email"
end
