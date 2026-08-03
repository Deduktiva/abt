module CurrencyHelper
  def current_currency
    @current_currency ||= Business.get_the_issuer!&.currency || "EUR"
  end

  def current_money_decimal_places
    @current_money_decimal_places ||= Business.get_the_issuer!&.money_decimal_places || 2
  end

  # Symbol for the issuer currency, falling back to the raw code. Single source
  # of truth — the invoice line-total JS reads this via a Stimulus value rather
  # than mapping symbols itself. Never carries a trailing space, so callers
  # always prepend it the same way.
  def currency_symbol
    case current_currency
    when "EUR" then "€"
    when "USD" then "$"
    when "GBP" then "£"
    else current_currency
    end
  end

  def format_currency(amount)
    return "" if amount.nil?
    "#{currency_symbol}#{sprintf("%.#{current_money_decimal_places}f", amount)}"
  end
end
