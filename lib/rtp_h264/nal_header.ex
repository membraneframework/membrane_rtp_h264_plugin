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
  A value of 00 indicates that the content of the NAL unit is not
  used to reconstruct reference pictures for inter picture prediction.
  Such NAL units can be discarded without risking the integrity
  of the reference pictures, although these payloads might contain metadata
  """
  @type nri :: 0..3

  @typedoc """
  Specifies the type of RBSP data structure contained in the NAL unit.
  """
  @type type :: 1..23

  defstruct [:nal_ref_idc, :type]

  @type t :: %__MODULE__{
          nal_ref_idc: nri(),
          type: type()
        }

  @doc """
  Parses NAL Header.
  """
  @spec parse_unit_header(binary()) :: {:error, :malformed_data} | {:ok, {t(), binary()}}
  def parse_unit_header(raw_nal)

  def parse_unit_header(<<0::1, nri::2, type::5, rest::binary()>>) do
    nal = %__MODULE__{
      nal_ref_idc: nri,
      type: type
    }

    {:ok, {nal, rest}}
  end

  # detect wether packet is malformed by that first 0 bit

  def parse_unit_header(<<_::binary()>>), do: {:error, :malformed_data}
end
