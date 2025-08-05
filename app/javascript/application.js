// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Enable Turbo Streams
import { Turbo } from "@hotwired/turbo-rails"
Turbo.config.drive.progressBarDelay = 100
