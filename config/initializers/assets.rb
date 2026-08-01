# SCSS sources in app/assets/stylesheets are compiled by dartsass-rails
# (rails dartsass:build / dartsass:watch) into app/assets/builds, which
# Propshaft serves. Propshaft is told to ignore the raw sources in
# config/application.rb (excluded_paths must be set before its engine
# initializer runs).
Rails.application.configure do
  # The bootstrap gem is require: false (its railtie is sprockets-only), so
  # hand its SCSS to Dart Sass as a plain load path instead of an asset path.
  bootstrap_scss = File.join(Gem.loaded_specs["bootstrap"].full_gem_path, "assets/stylesheets")
  config.dartsass.build_options << "--load-path=#{bootstrap_scss}"

  # Bootstrap 5.3 still uses @import internally; silence Dart Sass's
  # deprecation warnings for it (--quiet-deps covers load-path files,
  # --silence-deprecation=import our own entry point).
  config.dartsass.build_options << "--quiet-deps" << "--silence-deprecation=import"
end
