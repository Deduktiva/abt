source "https://rubygems.org"

gem "rails", "~> 8.1.3"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 6.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"


# Use database-backed adapters
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false


group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  # `require: false` so the app still boots in environments where the
  # development/test bundle isn't installed (e.g. production running bin/jobs).
  gem "debug", platforms: %i[ mri windows ], require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  gem "rubocop-rails-omakase", require: false
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "cuprite"
  # Opt-in test coverage: COVERAGE=1 bin/rails test (see test_helper.rb).
  gem "simplecov", require: false
  gem "simplecov-cobertura", require: false # Cobertura XML for Codecov in CI
end

group :test, :prod do
  gem "pg", "~> 1.6"
end

gem "config"

gem "sass-rails"  # necessary for bootstrap
gem "bootstrap", "~> 5.3"
gem "haml-rails"
gem "simple_form"

gem "mailgun-ruby", "~> 1.4.3"

gem "image_processing", "~> 2.0"

gem "webauthn", "~> 3.4"

# Rate-limit unauthenticated endpoints to mitigate brute-force and DoS attacks.
gem "rack-attack", "~> 6.7"

# ISO 3166 country list and EU/EEA membership data for the country dropdown.
gem "countries", "~> 8.1"

# EU VIES VAT ID lookup (SOAP), syntax + checksum validation per country.
gem "valvat", "~> 2.0"
