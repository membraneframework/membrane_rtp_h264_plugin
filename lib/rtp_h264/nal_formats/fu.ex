defmodule Membrane.Element.RTP.H264.FU do
  @moduledoc """
  Module responsible for parsing H264 Fragmentation Unit.
  """
  use Bunch
  alias Membrane.Element.RTP.H264.FU.Header
  alias Membrane.Element.RTP.H264.{Depayloader, NAL}

  defstruct [:last_seq_num, data: []]

  @type t :: %__MODULE__{
          data: [binary()],
          last_seq_num: nil | Depayloader.sequence_number()
        }

  defguardp next?(last_seq_num, next_seq_num) when last_seq_num + 1 == next_seq_num

  @doc """
  Parses H264 Fragmentation Unit

  If a packet that is being parsed is not considered last then a `{:incomplete, t()}`
  tuple  will be returned.
  In case of last packet `{:ok, {type, data}}` tuple will be returned, where data is `NAL Unit`
  created by concatenating subsequent Fragmentation Units.
  """

  @spec parse(binary(), Depayloader.sequence_number(), t) ::
          {:ok, {binary(), NAL.Header.type()}}
          | {:error, :packet_malformed | :invalid_first_packet}
          | {:incomplete, t()}
  def parse(data, seq_num, acc) do
    with {:ok, {header, value}} <- Header.parse(data) do
      do_parse(header, value, seq_num, acc)
    end
  end

  defp do_parse(header, data, seq_num, acc)

  defp do_parse(%Header{start_bit: true}, data, seq_num, acc),
    do: %__MODULE__{acc | data: [data], last_seq_num: seq_num} ~> {:incomplete, &1}

  defp do_parse(%Header{start_bit: false}, _, _, %__MODULE__{last_seq_num: nil}),
    do: {:error, :invalid_first_packet}

  defp do_parse(%Header{end_bit: true, type: type}, data, seq_num, %__MODULE__{
         data: acc,
         last_seq_num: last
       })
       when next?(last, seq_num) do
    result =
      [data | acc]
      |> Enum.reverse()
      |> Enum.join()

    {:ok, {result, type}}
  end

  defp do_parse(_header, data, seq_num, %__MODULE__{data: acc, last_seq_num: last} = fu)
       when next?(last, seq_num),
       do: {:incomplete, %__MODULE__{fu | data: [data | acc], last_seq_num: seq_num}}

  defp do_parse(_, _, _, _), do: {:error, :missing_packet}
end
