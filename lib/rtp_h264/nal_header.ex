defmodule Membrane.Element.RTP.H264.NALHeader do
  @moduledoc """
  Defines a structure representing Network Abstraction Layer Unit Header

  Defined in [RFC6184](https://tools.ietf.org/html/rfc6184#section-5.3)

  ```
      +---------------+
      |0|1|2|3|4|5|6|7|
      +-+-+-+-+-+-+-+-+
      |F|NRI|  Type   |
      +---------------+
  ```
  """

  @typedoc """
  This flag must be false (bit representing it must be 0).
  """
  @type is_damaged :: boolean()

  @typedoc """
  A value of 00 indicates that the content of the NAL unit is not
  used to reconstruct reference pictures for inter picture prediction.
  Such NAL units can be discarded without risking the integrity
  of the reference pictures
  """
  @type nri :: 0..3

  @typedoc """
  Specifies the type of RBSP data structure contained in the NAL unit.

  #TODO Remove me
  0 Not used
  1-23 Does not need processing?
  STAP-A 24
  STAP-B 25
  MTAP-16 26
  MTAP-24 27
  FU-A 28
  FU-B 29
  30-31 Reserved

  """
  @type type :: 1..23

  defstruct [:forbidden_zero, :nal_ref_idc, :type]

  @type t :: %__MODULE__{
          forbidden_zero: is_damaged(),
          nal_ref_idc: nri(),
          type: type()
        }

  @spec parse_unit_header(binary()) :: {:error, :malformed_data} | {:ok, {t(), binary()}}
  def parse_unit_header(raw_nal)

  def parse_unit_header(<<f::1, nri::2, type::5, rest::binary()>>) do
    nal = %__MODULE__{
      forbidden_zero: f,
      nal_ref_idc: nri,
      type: type
    }

    {:ok, {nal, rest}}
  end

  def parse_unit_header(<<_::binary()>>), do: {:error, :malformed_data}
end
