defmodule Membrane.Element.RTP.H264.FU do
  @moduledoc """
  Module responsible for parsing H264 Fragmentation Unit.
  """
  use Bunch
  alias Membrane.Element.RTP.H264.FU.Header
  alias Membrane.Element.RTP.H264.NALHeader
  alias Membrane.Element.RTP.H264.Depayloader

  defstruct data: []
  @type t :: %__MODULE__{}

  @doc """
  Parses H264 Fragmentation Unit

  If a packet that is being parsed is not considered last then a `{:incomplete, t()}`
  tuple  will be returned.
  In case of last packet `{:ok, {type, data}}` tuple will be returned, where data is `NAL Unit`
  created by concatenating subsequent Fragmentation Units.
  """
  @spec parse(binary(), Depayloader.sequence_number(), t) ::
          {:ok, {binary(), NALHeader.type()}} | {:error, :packet_malformed} | {:incomplete, t()}
  def parse(data, seq_num, acc) do
    data
    |> Header.parse()
    ~>> ({:ok, {header, value}} -> do_parse(header, value, seq_num, acc))
  end

  defp do_parse(header, data, seq_num, acc)

  defp do_parse(%Header{end_bit: true, type: type}, data, seq_num, %__MODULE__{data: acc}) do
    acc_data = [{seq_num, data} | acc]

    if is_sequence_invalid?(acc_data) do
      {:error, :missing_packet}
    else
      acc_data
      |> glue_accumulated_packets()
      ~> {:ok, {&1, type}}
    end
  end

  defp do_parse(%Header{start_bit: false}, _, _, %__MODULE__{data: []}),
    do: {:error, :invalid_first_packet}

  defp do_parse(_header, data, seq_num, %__MODULE__{data: acc} = fu),
    do: {:incomplete, %__MODULE__{fu | data: [{seq_num, data} | acc]}}

  defp is_sequence_invalid?([{first_seq_num, _} | data]) do
    data
    |> Enum.reduce_while(first_seq_num, fn
      {next, _}, prev when next + 1 == prev ->
        {:cont, next}

      _, _ ->
        {:halt, :discontinuity}
    end)
    ~> (&1 == :discontinuity)
  end

  defp glue_accumulated_packets(data) do
    Enum.reduce(data, <<>>, fn {_seq_num, data}, acc -> data <> acc end)
  end
end
