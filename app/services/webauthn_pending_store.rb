module WebauthnPendingStore
  TTL = 5.minutes

  def self.write(session:, flow:, **payload)
    nonce = SecureRandom.urlsafe_base64(32)
    Rails.cache.write(cache_key(flow, nonce), payload.stringify_keys, expires_in: TTL)
    session[session_key(flow)] = nonce
  end

  def self.consume(session:, flow:)
    nonce = session.delete(session_key(flow))
    return nil if nonce.blank?
    payload = Rails.cache.read(cache_key(flow, nonce))
    Rails.cache.delete(cache_key(flow, nonce))
    payload
  end

  def self.session_key(flow)
    "webauthn_#{flow}_nonce".to_sym
  end
  private_class_method :session_key

  def self.cache_key(flow, nonce)
    "webauthn:#{flow}:#{nonce}"
  end
  private_class_method :cache_key
end
