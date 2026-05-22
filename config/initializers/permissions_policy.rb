# Be sure to restart your server when you modify this file.
#
# Defines an application-wide Permissions Policy. Disables sensor / payment /
# device APIs the invoice app has no use for. `fullscreen` stays self-allowed
# so the browser's native PDF viewer (and email-preview iframe) can request it.

Rails.application.config.permissions_policy do |policy|
  policy.camera        :none
  policy.microphone    :none
  policy.geolocation   :none
  policy.gyroscope     :none
  policy.magnetometer  :none
  policy.accelerometer :none
  policy.usb           :none
  policy.payment       :none
  policy.fullscreen    :self
end
