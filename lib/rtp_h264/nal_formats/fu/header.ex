defmodule Membrane.Element.RTP.H264.FU.Header do
  @doc """
  Defines structure representing Fragmentation Unit (FU) header
  which is defined in [RFC6184](https://tools.ietf.org/html/rfc6184#page-31)

    +---------------+
    |0|1|2|3|4|5|6|7|
    +-+-+-+-+-+-+-+-+
    |S|E|R|  Type   |
    +---------------+
  """

  alias Membrane.Element.RTP.H264.NALHeader

  @type start_flag :: boolean()
  @type end_flag :: boolean()

  @enforce_keys [:type]
  defstruct start_bit: false, end_bit: false, reserved: false, type: 0

  @type t :: %__MODULE__{
          start_bit: start_flag(),
          end_bit: end_flag(),
          type: NALHeader.type()
        }

  defguard valid_frame_boundary(start, finish) when start != 1 or finish != 1

  @spec parse(binary()) :: {:ok, {t(), binary()}} | {:error, :packet_malformed}
  def parse(<<start::1, finish::1, 0::1, nal_type::5, rest::binary>>)
      when nal_type in 1..23 and valid_frame_boundary(start, finish) do
    header = %__MODULE__{
      start_bit: start,
      end_bit: finish,
      type: nal_type
    }

    {:ok, {header, rest}}
  end

  def parse(_), do: {:error, :packet_malformed}
end