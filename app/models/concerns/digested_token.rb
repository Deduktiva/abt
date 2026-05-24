module DigestedToken
  extend ActiveSupport::Concern

  class_methods do
    # Returns [plaintext, digest] suitable for storing the digest while
    # handing the plaintext back to the caller exactly once.
    def generate_token
      plaintext = SecureRandom.urlsafe_base64(32)
      [ plaintext, digest_token(plaintext) ]
    end

    def digest_token(plaintext)
      Digest::SHA256.hexdigest(plaintext)
    end
  end
end
