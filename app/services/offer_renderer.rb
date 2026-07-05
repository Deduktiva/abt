class OfferRenderer
  def initialize(version, issuer)
    @version = version
    @issuer = issuer
  end

  def render
    raise NotImplementedError
  end
end
