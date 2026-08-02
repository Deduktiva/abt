# Turning a document into follow-on billing documents must happen at most once:
# a double-clicked "Convert" button fires two requests that both read the
# not-yet-converted state and both create documents. #convert! reloads the
# source record under a row lock and runs the guards plus the writes in one
# transaction, so concurrent converts serialize and the loser sees the
# converted state and raises NotConvertible instead of double-billing.
#
# Includers supply #conversion_source (the record to lock) and #convert_locked!
# (guards plus writes).
module LockedConversion
  class NotConvertible < StandardError; end

  def convert!
    conversion_source.with_lock { convert_locked! }
  end
end
