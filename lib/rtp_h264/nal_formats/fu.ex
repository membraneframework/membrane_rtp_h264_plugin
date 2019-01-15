defmodule Membrane.Element.RTP.H264.FU do
  @moduledoc """
  Module responsible for parsing H264 Fragmentation Unit
  """
  use Bunch
  alias Membrane.Element.RTP.H264.FU.Header
  alias Membrane.Element.RTP.H264.Depayloader

  defstruct data: []
  @type t :: %__MODULE__{}

  @doc """
  Parses H264 Fragmentation Unit

  If packet that is being parsed is not considered last then tuple `{:incomplete, t()}` will be returned.
  In case of last packet `{:ok, data}` tuple will be returned, where data is `NALUnit`
  created by concatenating subsequent Fragmentation Units.
  """
  @spec parse(binary(), Depayloader.seq_num(), t) ::
          {:ok, binary()} | {:error, :packet_malformed} | {:incomplete, t()}
  def parse(data, seq_num, acc \\ %__MODULE__{}) do
    data
    |> Header.parse()
    ~>> ({:ok, {header, value}} -> do_parse(header, value, seq_num, acc))
  end

  defp do_parse(header, data, seq_num, acc)

  defp do_parse(%Header{end_bit: true} = header, data, seq_num, %__MODULE__{data: acc}) do
    acc_data = [{header, seq_num, data} | acc]

    if is_sequence_invalid?(acc_data) do
      {:error, :missing_packet}
    else
      {:ok, glue_accumulated_packets(acc_data)}
    end
  end

  defp do_parse(%Header{start_bit: false}, _, _, %__MODULE__{data: []}),
    do: {:error, :invalid_first_packet}

  defp do_parse(header, data, seq_num, %__MODULE__{data: acc} = fu),
    do: {:incomplete, %__MODULE__{fu | data: [{header, seq_num, data} | acc]}}

  defp is_sequence_invalid?(data) do
    data
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{_, a, _}, {_, b, _}] -> a - b end)
    |> Enum.reduce(&Kernel.-/2)
    ~> (&1 != 0)
  end

  defp glue_accumulated_packets(data) do
    Enum.reduce(data, <<>>, fn {_header, _seq_num, data}, acc -> data <> acc end)
  end
end
