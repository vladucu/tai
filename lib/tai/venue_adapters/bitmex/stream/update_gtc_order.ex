defmodule Tai.VenueAdapters.Bitmex.Stream.UpdateGtcOrder do
  alias Tai.VenueAdapters.Bitmex.ClientId

  @date_format "{ISO:Extended}"

  def update(venue_client_id, %{"ordStatus" => venue_status} = venue_order) do
    client_id = venue_client_id |> ClientId.from_base64()

    venue_status
    |> from_venue_status()
    |> passive_update(client_id, venue_order)
    |> notify
  end

  defp from_venue_status(venue_status) do
    Tai.VenueAdapters.Bitmex.OrderStatus.from_venue_status(venue_status, :ignore)
  end

  defp passive_update(
         :filled,
         client_id,
         %{"timestamp" => timestamp, "avgPx" => avg_px, "cumQty" => cum_qty}
       ) do
    venue_updated_at = timestamp |> Timex.parse!(@date_format)
    avg_price = avg_px |> Tai.Utils.Decimal.from()
    cumulative_qty = cum_qty |> Tai.Utils.Decimal.from()

    result =
      Tai.Trading.OrderStore.passive_fill(
        client_id,
        venue_updated_at,
        avg_price,
        cumulative_qty
      )

    {client_id, :passive_fill, result}
  end

  defp passive_update(
         :open,
         client_id,
         %{
           "timestamp" => timestamp,
           "avgPx" => avg_px,
           "cumQty" => cum_qty,
           "leavesQty" => lvs_qty
         }
       ) do
    venue_updated_at = timestamp |> Timex.parse!(@date_format)
    avg_price = avg_px |> Tai.Utils.Decimal.from()
    cumulative_qty = cum_qty |> Tai.Utils.Decimal.from()
    leaves_qty = lvs_qty |> Tai.Utils.Decimal.from()

    result =
      Tai.Trading.OrderStore.passive_partial_fill(
        client_id,
        venue_updated_at,
        avg_price,
        cumulative_qty,
        leaves_qty
      )

    {client_id, :passive_partial_fill, result}
  end

  defp passive_update(:canceled, client_id, %{"timestamp" => timestamp}) do
    venue_updated_at = timestamp |> Timex.parse!(@date_format)
    result = Tai.Trading.OrderStore.passive_cancel(client_id, venue_updated_at)
    {client_id, :passive_cancel, result}
  end

  defp notify({_, _, {:ok, {old, updated}}}) do
    Tai.Trading.Orders.updated!(old, updated)
  end

  defp notify({client_id, action, {:error, {:invalid_status, was, required}}}) do
    Tai.Events.broadcast(%Tai.Events.OrderUpdateInvalidStatus{
      client_id: client_id,
      action: action,
      was: was,
      required: required
    })
  end
end