defmodule Tai.Venues.Execution do
  alias __MODULE__

  @type venue_id :: Tai.Venue.id()
  @type credential_id :: Tai.Venue.credential_id()
  @type product_symbol :: Tai.Venue.Product.symbol()
  @type t :: %Execution{
          venue_id: venue_id,
          credential_id: credential_id,
          symbol: product_symbol
        }

  @enforce_keys ~w(
    venue_id
    credential_id
    symbol
  )a
  defstruct ~w(
    venue_id
    credential_id
    symbol
  )a
end

defimpl Stored.Item, for: Tai.Venues.Execution do
  @type key :: term
  @type execution :: Tai.Venues.Execution.t()

  @spec key(execution) :: key
  def key(a), do: {a.venue_id, a.credential_id, a.symbol}
end
