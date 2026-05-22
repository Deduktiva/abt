# Be sure to restart your server when you modify this file.
#
# Defines an application-wide Content Security Policy. The policy is strict:
# no 'unsafe-inline' or 'unsafe-eval'. The few legitimately-inline elements
# (the layout's theme-detection script and per-page `<style>` blocks for the
# issuer accent color) are nonced.

Rails.application.config.content_security_policy do |policy|
  policy.default_src     :self
  policy.script_src      :self
  policy.style_src       :self
  policy.img_src         :self, :data
  policy.font_src        :self
  policy.connect_src     :self
  policy.object_src      :none
  policy.base_uri        :self
  policy.form_action     :self
  policy.frame_ancestors :none
end

Rails.application.config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src style-src]
