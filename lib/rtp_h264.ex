defmodule Membrane.Element.RtpH264 do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = []

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
