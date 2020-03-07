defmodule Tai.Commands.Executions do
  @moduledoc """
  Display the list of executions and their details
  """

  import Tai.Commands.Table, only: [render!: 2]

  @header [
    "Venue",
    "Credential",
    "Product"
  ]
  @cols ~w(
    venue_id,
    credential_id,
    product_symbol
  )a
  @order ~w(
    venue_id
    credential_id
    product_symbol
  )a

  @spec executions :: no_return
  def executions do
    Tai.Trading.ExecutionStore.all()
    |> Enumerati.order(@order)
    |> Enum.map(fn e ->
      @cols
      |> Enum.map(&Map.get(e, &1))
    end)
    |> render!(@header)
  end
end
