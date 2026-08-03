# Serializes conversion into billing documents: #convert! reloads the source row
# under a lock, so a double-clicked "Convert" hits the converted state instead of
# double-billing. Includers supply #conversion_source (the row to lock) and
# #convert_locked! (guards plus writes), raise their own NotConvertible subclass
# so callers can tell converters apart, and — since only the source row is
# reloaded — re-read anything else their guards consult.
module LockedConversion
  class NotConvertible < StandardError; end

  def convert!
    conversion_source.with_lock { convert_locked! }
  end
end
