defmodule Membrane.Element.RTP.H264.Depayloader do
  @moduledoc """
  Depayloads H264 RTP payloads into H264 NAL Units.
  """
  use Membrane.Element.Base.Filter
  use Bunch
  use Membrane.Log

  alias Membrane.Caps.{RTP, Video.H264}
  alias Membrane.Event.Discontinuity

  @frame_prefix <<1::32>>
  @type sequence_number :: 0..65_535

  def_output_pads output: [
                    caps: {H264, stream_format: :byte_stream}
                  ]

  def_input_pads input: [
                   caps: {RTP, payload_type: :dynamic},
                   demand_unit: :buffers
                 ]

  alias Membrane.Element.RTP.H264.NALHeader
  alias NALHeader.PayloadTypeDecoder
  alias Membrane.Element.RTP.H264.{FU, StapA}
  alias Membrane.Buffer

  defmodule State do
    @moduledoc false
    # pp_acc, stands for packet parser accumulator
    defstruct pp_acc: nil
  end

  def handle_init(_) do
    {:ok, %State{}}
  end

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(_pad, %Buffer{payload: payload} = buffer, _ctx, state) do
    NALHeader.parse_unit_header(payload)
    ~>> ({:ok, {header, rest}} ->
           case PayloadTypeDecoder.decode_type(header.type) do
             :single_nalu ->
               buffer_output(payload, buffer)

             :fu_a ->
               handle_fu(header, rest, buffer, state)

             :stap_a ->
               handle_stap(rest, buffer)
           end)
    ~>> ({:error, _} ->
           log_malformed_buffer(buffer)
           {{:ok, redemand: :output}, %State{state | pp_acc: nil}})
  end

  @impl true
  def handle_demand(_output_pad, size, :buffers, _ctx, state),
    do: {{:ok, demand: {:input, size}}, state}

  @impl true
  def handle_event(:input, %Discontinuity{}, _context, %State{pp_acc: %FU{}} = state),
    do: {:ok, %State{state | pp_acc: nil}}

  def handle_event(_pad, event, _context, state), do: {{:ok, forward: event}, state}

  defp handle_fu(header, data, %Buffer{metadata: metadata} = buffer, state) do
    %{rtp: %{sequence_number: seq_num}} = metadata

    FU.parse(data, seq_num, map_state_to_fu(state))
    ~>> (
      {:ok, {data, type}} ->
        header = <<0::1, header.nal_ref_idc::2, type::5>>
        data = header <> data
        buffer_output(data, buffer)

      {:incomplete, fu} ->
        {{:ok, redemand: :output}, %State{state | pp_acc: fu}}
    )
  end

  defp handle_stap(data, buffer) do
    data
    |> StapA.parse()
    ~>> ({:ok, result} ->
           result
           |> Enum.flat_map(&action_from_data(&1, buffer))
           ~> {{:ok, &1}, %State{}})
  end

  defp buffer_output(data, buffer),
    do: {{:ok, action_from_data(data, buffer)}, %State{}}

  defp action_from_data(data, buffer) do
    data
    |> add_prefix()
    ~> [buffer: {:output, %Buffer{buffer | payload: &1}}]
  end

  defp add_prefix(stream), do: @frame_prefix <> stream

  defp map_state_to_fu(%State{pp_acc: %FU{} = fu}), do: fu
  defp map_state_to_fu(_), do: %FU{}

  defp log_malformed_buffer(%Buffer{metadata: metadata}) do
    %{rtp: %{sequence_number: seq_num}} = metadata

    warn("""
    An error occurred while parsing RTP frame with sequence_number: #{seq_num}
    """)
  end
end
