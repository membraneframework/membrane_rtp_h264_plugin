defmodule Membrane.Element.RTP.H264.StapA do
  @moduledoc """
  Module responsible for parsing Single Time Agregation Packets type A.
  Documented in [RFC6184](https://tools.ietf.org/html/rfc6184#page-20)

  ```
   0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                          RTP Header                           |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |STAP-A NAL HDR |         NALU 1 Size           | NALU 1 HDR    |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                         NALU 1 Data                           |
    :                                                               :
    +               +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |               | NALU 2 Size                   | NALU 2 HDR    |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                         NALU 2 Data                           |
    :                                                               :
    |                               +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                               :...OPTIONAL RTP padding        |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  ```
  """
  use Bunch

  @doc """
  Parses a STAP type A
  """
  @spec parse(binary()) :: {:ok, [binary()]} | {:error, :packet_malformed}
  def parse(data) do
    data
    |> parse_batch()
    ~>> ({:ok, value} -> {:ok, Enum.reverse(value)})
  end

  defp parse_batch(data, acc \\ [])
  defp parse_batch(<<>>, acc), do: {:ok, acc}

  defp parse_batch(
         <<size::16, nalu_hdr::binary-size(1), nalu::binary-size(size), rest::binary>>,
         acc
       ),
       do: parse_batch(rest, [nalu_hdr <> nalu | acc])

  defp parse_batch(_, _), do: {:error, :packet_malformed}
end
