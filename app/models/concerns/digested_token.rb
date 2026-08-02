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

    # Digest of a token supplied by a request, or nil when it cannot identify a
    # record. Tokens arrive from params and cookies, so a caller can send an
    # Array (`?token[]=a&token[]=b`) or nested Parameters instead of a string;
    # both raise in the digest. Never returns a digest of a blank token, so a
    # lookup can't match a row whose digest column is empty.
    def lookup_digest(plaintext)
      digest_token(plaintext) if plaintext.is_a?(String) && plaintext.present?
    end
  end
end
