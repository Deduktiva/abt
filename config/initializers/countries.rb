Rails.application.config.after_initialize do
  ISO3166.configure do |config|
    config.locales = I18n.available_locales
  end
end
