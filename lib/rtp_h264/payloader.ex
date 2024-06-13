defmodule Membrane.RTP.H264.Payloader do
  @moduledoc """
  Payloads H264 NAL Units into H264 RTP payloads.

  Based on [RFC 6184](https://tools.ietf.org/html/rfc6184)

  Supported types: Single NALU, FU-A, STAP-A.
  """

  use Bunch
  use Membrane.Filter

  alias Membrane.Buffer
  alias Membrane.RTP
  alias Membrane.RTP.H264.{FU, StapA}

  def_options max_payload_size: [
                spec: non_neg_integer(),
                default: 1400,
                description: """
                Maximal size of outputted payloads in bytes. Doesn't work in
                the `single_nalu` mode. The resulting RTP packet will also contain
                RTP header (12B) and potentially RTP extensions. For most
                applications, everything should fit in standard MTU size (1500B)
                after adding L3 and L2 protocols' overhead.
                """
              ],
              mode: [
                spec: :single_nalu | :non_interleaved,
                default: :non_interleaved,
                description: """
                In `:single_nalu` mode, payloader puts exactly one NAL unit
                into each payload, altering only RTP metadata. `:non_interleaved`
                mode handles also FU-A and STAP-A packetization. See
                [RFC 6184](https://tools.ietf.org/html/rfc6184) for details.
                """
              ]

  def_input_pad :input,
    accepted_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb}

  def_output_pad :output, accepted_format: RTP

  defmodule State do
    @moduledoc false
    defstruct [
      :max_payload_size,
      :mode,
      stap_acc: %{
        payloads: [],
        # header size
        byte_size: 1,
        pts: 0,
        dts: 0,
        metadata: nil,
        nri: 0,
        f: 0
      }
    ]
  end

  @impl true
  def handle_init(_ctx, opts) do
    {[], Map.merge(%State{}, Map.from_struct(opts))}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[stream_format: {:output, %RTP{}}], state}
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _context, state) do
    {[], state}
  end

  @impl true
  def handle_buffer(:input, %Buffer{} = buffer, _ctx, state) do
    buffer = Map.update!(buffer, :payload, &delete_prefix/1)

    {buffers, state} =
      withl mode: :non_interleaved <- state.mode,
            single_nalu: :deny <- try_single_nalu(buffer, state) do
        {use_fu_a(buffer, state), state}
      else
        mode: :single_nalu -> {use_single_nalu(buffer), state}
        stap_a: {:accept, buffers, state} -> {buffers, state}
        single_nalu: {:accept, buffer} -> {[buffer], state}
      end

    {[buffer: {:output, buffers}], state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {[end_of_stream: :output], state}
  end

  defp delete_prefix(<<0, 0, 0, 1, nal::binary>>), do: nal
  defp delete_prefix(<<0, 0, 1, nal::binary>>), do: nal

  defp try_single_nalu(buffer, state) do
    if byte_size(buffer.payload) <= state.max_payload_size do
      {:accept, use_single_nalu(buffer)}
    else
      :deny
    end
  end

  defp use_single_nalu(buffer) do
    set_marker(buffer)
  end

  defp use_fu_a(buffer, state) do
    buffer.payload
    |> FU.serialize(state.max_payload_size)
    |> Enum.map(&%Buffer{buffer | payload: &1})
    |> Enum.map(&clear_marker/1)
    |> List.update_at(-1, &set_marker/1)
  end

  defp set_marker(buffer) do
    marker = Map.get(buffer.metadata.h264, :end_access_unit, false)
    Bunch.Struct.put_in(buffer, [:metadata, :rtp], %{marker: marker})
  end

  defp clear_marker(buffer) do
    Bunch.Struct.put_in(buffer, [:metadata, :rtp], %{marker: false})
  end
end
