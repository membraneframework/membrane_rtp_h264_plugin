defmodule Membrane.Support.Helper do
  @moduledoc false
  alias Membrane.Buffer
  alias Membrane.Event.EndOfStream

  def into_rtp_buffer(data, seq_num \\ 0, timestamp \\ 0),
    do: %Buffer{
      payload: data,
      metadata: %{rtp: %{sequence_number: seq_num, timestamp: timestamp}}
    }

  def generator_from_data(data) do
    fun = fn state, size ->
      {buffers, leftover} = Enum.split(state, size)
      buffer_action = [{:buffer, {:output, buffers}}]
      event_action = if leftover == [], do: [{:event, {:output, %EndOfStream{}}}], else: []
      to_send = buffer_action ++ event_action
      {to_send, leftover}
    end

    {data, fun}
  end
end
