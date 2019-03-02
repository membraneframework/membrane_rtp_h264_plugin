defmodule Membrane.Element.RTP.H264.NALHeader.PayloadTypeDecoder do
  @moduledoc """
  Module responsible for parsing Types stored in NAL Headers.

  Types are defined as follows.

  | ID       | RBSP Type      |
  |----------|----------------|
  | 0        | Unspecified    |
  | 1-23     | NAL unit types |
  | 24       | STAP-A         |
  | 25       | STAP-B         |
  | 26       | MTAP-16        |
  | 27       | MTAP-24        |
  | 28       | FU-A           |
  | 29       | FU-B           |
  | Reserved | 30-31          |

  RBSP stands for Raw Byte Sequence Payload

  RBSP types are described in detail [here](https://yumichan.net/video-processing/video-compression/introduction-to-h264-nal-unit)
  """

  @type supported_types :: :stap_a | :fu_a
  @type unsupported_types :: :stap_b | :mtap_16 | :mtap_24 | :fu_b
  @type types :: :single_nalu | supported_types | unsupported_types | :reserved

  @spec decode_type(1..31) :: types()
  def decode_type(number)

  def decode_type(number) when number in 1..21, do: :single_nalu
  def decode_type(24), do: :stap_a
  def decode_type(25), do: :stap_b
  def decode_type(26), do: :mtap_16
  def decode_type(27), do: :mtap_24
  def decode_type(28), do: :fu_a
  def decode_type(29), do: :fu_b
  def decode_type(number) when number in 30..31 or number in [22, 23], do: :reserved
end
