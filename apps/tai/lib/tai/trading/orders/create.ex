defmodule Tai.Trading.Orders.Create do
  alias Tai.Trading.OrderStore.Actions

  alias Tai.Trading.{
    OrderStore,
    OrderResponses,
    Order,
    OrderSubmissions
  }

  @type order :: Order.t()
  @type submission :: OrderSubmissions.Factory.submission()
  @type response :: {:ok, order}

  @spec create(submission) :: response
  def create(submission) do
    {:ok, order} = OrderStore.enqueue(submission)

    Task.async(fn ->
      if Tai.Settings.send_orders?() do
        try do
          order
          |> send_to_venue()
          |> parse_response()
          |> parse_result()
        rescue
          e ->
            {e, __STACKTRACE__}
            |> rescue_venue_adapter_error(order)
            |> parse_result()
        end
      else
        order.client_id
        |> skip!
        |> parse_result()
      end
    end)

    {:ok, order}
  end

  defp send_to_venue(order) do
    result = Tai.Venue.create_order(order)
    {result, order}
  end

  defp parse_response({
         {:ok, %OrderResponses.CreateAccepted{} = response},
         order
       }) do
    %Actions.AcceptCreate{
      client_id: order.client_id,
      venue_order_id: response.id,
      last_received_at: response.received_at,
      last_venue_timestamp: response.venue_timestamp
    }
    |> OrderStore.update()
  end

  defp parse_response({
         {:ok, %OrderResponses.Create{status: :open} = response},
         order
       }) do
    %Actions.Open{
      client_id: order.client_id,
      venue_order_id: response.id,
      cumulative_qty: response.cumulative_qty,
      leaves_qty: response.leaves_qty,
      last_received_at: response.received_at,
      last_venue_timestamp: response.venue_timestamp
    }
    |> OrderStore.update()
  end

  defp parse_response({
         {:ok, %OrderResponses.Create{status: :filled} = response},
         order
       }) do
    %Actions.Fill{
      client_id: order.client_id,
      venue_order_id: response.id,
      cumulative_qty: response.cumulative_qty,
      last_received_at: response.received_at,
      last_venue_timestamp: response.venue_timestamp
    }
    |> OrderStore.update()
  end

  defp parse_response({
         {:ok, %OrderResponses.Create{status: :expired} = response},
         order
       }) do
    %Actions.Expire{
      client_id: order.client_id,
      venue_order_id: response.id,
      cumulative_qty: response.cumulative_qty,
      leaves_qty: response.leaves_qty,
      last_received_at: response.received_at,
      last_venue_timestamp: response.venue_timestamp
    }
    |> OrderStore.update()
  end

  defp parse_response({
         {:ok, %OrderResponses.Create{status: :rejected} = response},
         order
       }) do
    %Actions.Reject{
      client_id: order.client_id,
      venue_order_id: response.id,
      last_received_at: response.received_at,
      last_venue_timestamp: response.venue_timestamp
    }
    |> OrderStore.update()
  end

  defp parse_response({{:error, reason}, order}) do
    %Actions.CreateError{
      client_id: order.client_id,
      reason: reason,
      last_received_at: Timex.now()
    }
    |> OrderStore.update()
  end

  defp rescue_venue_adapter_error(reason, order) do
    %Actions.CreateError{
      client_id: order.client_id,
      reason: {:unhandled, reason},
      last_received_at: Timex.now()
    }
    |> OrderStore.update()
  end

  defp skip!(client_id) do
    %Actions.Skip{
      client_id: client_id
    }
    |> OrderStore.update()
  end

  defp parse_result({:ok, _}), do: :ok

  defp parse_result({:error, {:invalid_status, _, _, %action_name{}}})
       when action_name == Actions.AcceptCreate do
    :ok
  end
end
