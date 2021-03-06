defmodule Tai.Markets.QuoteStore do
  use Stored.Store

  @topic_namespace :market_quote_store

  def after_put(market_quote) do
    Tai.SystemBus.broadcast(
      {@topic_namespace, {market_quote.venue_id, market_quote.product_symbol}},
      {@topic_namespace, :after_put, market_quote}
    )
  end
end
