defmodule Tai.VenueAdapters.Bitmex.Stream.Connection do
  use WebSockex
  require Logger

  @type t :: %Tai.VenueAdapters.Bitmex.Stream.Connection{
          venue_id: atom
        }

  @enforce_keys [:venue_id]
  defstruct [:venue_id]

  def start_link(url: url, venue_id: venue_id, products: products) do
    conn = %Tai.VenueAdapters.Bitmex.Stream.Connection{venue_id: venue_id}
    {:ok, pid} = WebSockex.start_link(url, __MODULE__, conn, name: :"#{__MODULE__}_#{venue_id}")
    subscribe(pid, products)
    {:ok, pid}
  end

  def handle_connect(_conn, state) do
    Tai.Events.broadcast(%Tai.Events.StreamConnectionOk{venue_id: state.venue_id})
    {:ok, state}
  end

  def handle_disconnect(conn_status, state) do
    Tai.Events.broadcast(%Tai.Events.StreamDisconnect{
      venue_id: state.venue_id,
      reason: conn_status.reason
    })

    {:ok, state}
  end

  def handle_frame({:text, msg}, state) do
    Logger.debug(fn -> "Received raw msg: #{msg}" end)

    msg
    |> Poison.decode!()
    |> handle_msg(state.venue_id)

    {:ok, state}
  end

  def handle_frame(_frame, state), do: {:ok, state}

  defp subscribe(pid, products) do
    args = Enum.map(products, fn p -> "orderBookL2_25:#{p.exchange_symbol}" end)
    msg = %{"op" => "subscribe", "args" => args}
    Tai.WebSocket.send_json_msg(pid, msg)
  end

  @spec handle_msg(msg :: map, venue_id :: atom) :: no_return
  defp handle_msg(msg, venue_id)

  defp handle_msg(%{"limit" => %{"remaining" => remaining}, "version" => _}, venue_id) do
    Tai.Events.broadcast(%Tai.Events.BitmexStreamConnectionLimitDetails{
      venue_id: venue_id,
      remaining: remaining
    })
  end

  defp handle_msg(%{"request" => _, "subscribe" => _} = msg, venue_id) do
    venue_id |> process_order_books(msg)
  end

  defp handle_msg(%{"action" => "partial"} = msg, venue_id) do
    venue_id |> process_order_books(msg)
  end

  defp handle_msg(%{"action" => "insert"} = msg, venue_id) do
    venue_id |> process_order_books(msg)
  end

  defp handle_msg(%{"action" => "update"} = msg, venue_id) do
    venue_id |> process_order_books(msg)
  end

  defp handle_msg(%{"action" => "delete"} = msg, venue_id) do
    venue_id |> process_order_books(msg)
  end

  defp handle_msg(msg, venue_id) do
    Tai.Events.broadcast(%Tai.Events.StreamMessageUnhandled{venue_id: venue_id, msg: msg})
  end

  defp process_order_books(venue_id, msg) do
    venue_id
    |> Tai.VenueAdapters.Bitmex.Stream.ProcessOrderBooks.to_name()
    |> GenServer.cast({msg, Timex.now()})
  end
end