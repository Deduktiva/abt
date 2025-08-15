source 'https://rubygems.org'

gem 'rails', '~> 8.0.2'
gem 'puma', '~> 6.0'
gem 'solid_cache'

group :dev do
  gem 'sqlite3', '~> 2.7'
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '~> 3.5'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.1.0'
  # Rails 8 default debugger
  gem 'debug', '>= 1.0.0'
end

group :test, :prod do
  gem 'pg', '~> 1.6'
end

gem 'config'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.18.0', require: false
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.14'

# Rails hotwire
gem 'importmap-rails'
gem 'turbo-rails'
gem 'stimulus-rails'

gem 'sass-rails', '>= 6'
gem 'uglifier', '>= 1.3.0'

gem 'bootstrap', '~> 5.3'
gem 'haml-rails'
gem 'simple_form'

gem "mailgun-ruby", "~> 1.3.9"

group :test do
  gem 'capybara', '~> 3.40'
  gem 'cuprite'
end
