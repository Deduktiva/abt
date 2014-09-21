class Rfc4648Base32
  def self.i_to_s(val)
    val.to_s(base=32).tr('0123456789abcdefghijklmnopqrstuv', 'abcdefghijklmnopqrstuvwxyz234567')
  end

  def self.s_to_i(val)
    val.tr('abcdefghijklmnopqrstuvwxyz234567', '0123456789abcdefghijklmnopqrstuv').to_i
  end
end
