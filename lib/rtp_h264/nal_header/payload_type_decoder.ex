defmodule Membrane.Element.RTP.H264.NALHeader.PayloadTypeDecoder do
  @moduledoc """
  Module responsible for parsing Types stored in NALHEaders.

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

  For more information about RBSP types see `t:rbsp_types`.
  """

  @typedoc """
  RBSP stands for Raw Byte Sequence Payload

  RBSP types are described in detail [here](https://yumichan.net/video-processing/video-compression/introduction-to-h264-nal-unit)
  """
  @type rbsp_types :: :rbsp_type
  @type stap_a :: :stap_a
  @type stap_b :: :stap_b
  @type mtap_16 :: :mtap_16
  @type mtap_24 :: :mtap_24
  @type fu_a :: :fu_a
  @type fu_b :: :fu_b
  @type reserved :: :reserved

  @type supported_types :: stap_a | fu_a
  @type unsupported_types :: stap_b | mtap_16 | mtap_24 | fu_b
  @type types :: rbsp_types | supported_types | unsupported_types

  @spec decode_type(1..31) :: types()
  def decode_type(number)

  def decode_type(number) when number in 1..21, do: :rbsp_type
  def decode_type(24), do: :stap_a
  def decode_type(25), do: :stab_b
  def decode_type(26), do: :mtap_16
  def decode_type(27), do: :mtap_24
  def decode_type(28), do: :fu_a
  def decode_type(29), do: :fu_b
  def decode_type(number) when number in 30..31, do: :reserved

  def is_supported(supported) when supported in [:stap_a, :fu_a, :rbsp_type], do: true
  def is_supported(_), do: false
end
