defmodule Membrane.Element.RTP.H264.FU do
  use Bunch
  alias Membrane.Element.RTP.H264.FU.Header
  # A fragmented NAL unit MUST NOT be transmitted in one FU; that is, the
  #  Start bit and End bit MUST NOT both be set to one in the same FU
  #  header.
  # {toilet: true}
  # {toilet: %{prefered_size, warn}}

  defstruct data: []
  @type t :: %__MODULE__{}

  @spec parse(binary(), any(), t) :: {:ok, binary()} | {:error, :packet_malformed}
  def parse(data, seq_num, acc \\ %__MODULE__{}) do
    data
    |> Header.parse()
    ~>> ({:ok, {header, value}} -> do_parse(header, value, seq_num, acc))
  end

  @spec do_parse(Header.t(), binary(), number(), t) :: {:ok, t} | {:error, atom()}
  defp do_parse(header, data, seq_num, acc)

  defp do_parse(%Header{end_bit: 1} = header, data, seq_num, %__MODULE__{data: acc}) do
    acc_data = [{header, seq_num, data} | acc]

    if is_sequence_invalid?(acc_data) do
      {:error, :missing_packet}
    else
      {:ok, glue_accumulated_packets(acc_data)}
    end
  end

  defp do_parse(%Header{start_bit: 0}, _, _, %__MODULE__{data: []}),
    do: {:error, :invalid_first_packet}

  defp do_parse(header, data, seq_num, %__MODULE__{data: acc} = fu) do
    {:incomplete, %__MODULE__{fu | data: [{header, seq_num, data} | acc]}}
  end

  defp is_sequence_invalid?(data) do
    data
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{_, a, _}, {_, b, _}] -> a - b end)
    |> Enum.reduce(&Kernel.-/2)
    |> Kernel.!=(0)
  end

  defp glue_accumulated_packets(data) do
    Enum.reduce(data, <<>>, fn {_header, _seq_num, data}, acc ->
      data <> acc
    end)
  end
end
