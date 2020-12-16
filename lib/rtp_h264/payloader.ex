defmodule Membrane.RTP.H264.Payloader do
  @moduledoc """
  Payloads H264 NAL Units into H264 RTP payloads.

  Based on [RFC 6184](https://tools.ietf.org/html/rfc6184)

  Supported types: Single NALU, FU-A, STAP-A.
  """

  use Membrane.Filter
  use Membrane.Log

  alias Membrane.Buffer
  alias Membrane.{RTP, RemoteStream}
  alias Membrane.Caps.Video.H264
  alias Membrane.RTP.H264.{FU, NAL, StapA}

  @frame_prefix_shorter <<1::24>>
  @frame_prefix_longer <<1::32>>
  @min_single_size 512
  @preferred_size 1024
  @max_single_size 1200

  @empty_stap_acc %{
    payloads: [],
    byte_size: 0,
    metadata: nil,
    stap_a_nri: 0,
    stap_a_reserved: 0
  }

  def_options min_single_size: [
                spec: non_neg_integer(),
                default: @min_single_size,
                description: """
                Minimal byte size for Single NALU. Units smaller than it will be aggregated
                in STAP-A payloads.
                """
              ],
              max_single_size: [
                spec: pos_integer(),
                default: @max_single_size,
                description: """
                Maximal byte size for Single NALU. Units bigger than it will be fragmented
                into FU-A payloads.
                """
              ],
              preferred_size: [
                spec: pos_integer(),
                default: @preferred_size,
                description: """
                Byte size which will be a target for Payloader. During fragmentation
                into FU-A payloads, every (but last) payload will be of preferred size. During
                aggregation into STAP-A payloads Payloader will send payload if it exceeds
                preferred size.
                """
              ]

  def_input_pad :input,
    caps: {H264, stream_format: :byte_stream, alignment: :nal},
    demand_unit: :buffers

  def_output_pad :output, caps: RTP

  defmodule State do
    @moduledoc false
    defstruct [
      :max_single_size,
      :min_single_size,
      :preferred_size,
      :payload_type,
      :stap_acc
    ]
  end

  @impl true
  def handle_init(options) do
    {:ok, Map.merge(%State{stap_acc: @empty_stap_acc}, Map.from_struct(options))}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, caps: {:output, %RTP{}}}, state}
  end

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: payload} = buffer, _ctx, state) do
    type = get_unit_type(payload, state)
    {acc_buffers, state} = handle_accumulator(type, buffer, state)
    {new_buffers, state} = handle_unit_type(type, buffer, state)
    {{:ok, buffer: {:output, acc_buffers ++ new_buffers}, redemand: :output}, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    {buffers, state} = flush_accumulator(state)
    {{:ok, buffer: {:output, buffers}, end_of_stream: :output}, state}
  end

  defp get_unit_type(payload, state) do
    size = byte_size(payload)

    cond do
      size < state.min_single_size -> :stap_a
      size < state.max_single_size -> :single_nalu
      true -> :fu_a
    end
  end

  defp handle_accumulator(
         :stap_a,
         %Buffer{payload: payload, metadata: %{timestamp: timestamp}},
         %{
           stap_acc: %{metadata: %{timestamp: timestamp}, byte_size: size},
           max_single_size: max_size
         } = state
       )
       when size + byte_size(payload) < max_size,
       do: {[], state}

  defp handle_accumulator(_type, _buffer, state), do: flush_accumulator(state)

  defp flush_accumulator(%{stap_acc: stap_acc} = state) do
    buffers =
      case stap_acc.payloads do
        [] ->
          []

        [payload] ->
          payload = StapA.delete_size(payload)
          [%Buffer{payload: payload, metadata: stap_acc.metadata} |> set_marker()]

        payloads ->
          r = stap_acc.stap_a_reserved
          nri = stap_acc.stap_a_nri

          payload =
            payloads
            |> Enum.reverse()
            |> IO.iodata_to_binary()
            |> NAL.Header.add_header(r, nri, NAL.Header.encode_type(:stap_a))

          [%Buffer{payload: payload, metadata: stap_acc.metadata} |> set_marker()]
      end

    {buffers, %{state | stap_acc: @empty_stap_acc}}
  end

  defp handle_unit_type(:single_nalu, buffer, state) do
    buffer = Map.update!(buffer, :payload, &delete_prefix/1) |> set_marker()
    {[buffer], state}
  end

  defp handle_unit_type(:fu_a, buffer, state) do
    buffers =
      buffer.payload
      |> delete_prefix
      |> FU.fragmentate(state.preferred_size)
      |> Enum.map(&%Buffer{buffer | payload: &1})
      |> Enum.map(&Bunch.Struct.put_in(&1, [:metadata, :rtp], %{marker: false}))
      |> List.update_at(-1, &set_marker/1)

    {buffers, state}
  end

  defp handle_unit_type(:stap_a, buffer, state) do
    state = update_stap_a_properties(delete_prefix(buffer.payload), buffer.metadata, state)
    {[], state}
  end

  defp delete_prefix(@frame_prefix_longer <> rest), do: rest
  defp delete_prefix(@frame_prefix_shorter <> rest), do: rest

  defp update_stap_a_properties(
         <<r::1, nri::2, _type::5, _rest::binary()>> = payload,
         metadata,
         %{stap_acc: stap_acc} = state
       ) do
    payload = StapA.add_size(payload)

    stap_acc = %{
      stap_acc
      | payloads: [payload | stap_acc.payloads],
        byte_size: stap_acc.byte_size + byte_size(payload),
        metadata: stap_acc.metadata || metadata,
        stap_a_reserved: stap_acc.stap_a_reserved * r,
        stap_a_nri: min(stap_acc.stap_a_nri, nri)
    }

    %{state | stap_acc: stap_acc}
  end

  defp set_marker(buffer) do
    marker = Map.has_key?(buffer.metadata.h264, :end_access_unit)
    Bunch.Struct.put_in(buffer, [:metadata, :rtp], %{marker: marker})
  end
end
