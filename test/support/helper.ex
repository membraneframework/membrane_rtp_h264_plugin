defmodule Membrane.Support.Helper do
  @moduledoc false
  alias Membrane.Buffer

  def into_rtp_buffer(data, seq_num \\ 0, timestamp \\ 0),
    do: %Buffer{
      payload: data,
      metadata: %{rtp: %{sequence_number: seq_num, timestamp: timestamp}}
    }
end
