defmodule Membrane.Element.RTP.H264.Depayloader do
  @moduledoc """
  Depayloads H264 RTP payloads into H264 NAL Units.
  """
  use Membrane.Element.Base.Filter
  use Bunch
  use Membrane.Log

  alias Membrane.Buffer
  alias Membrane.Caps.{RTP, Video.H264}
  alias Membrane.Event.Discontinuity
  alias Membrane.Element.RTP.H264.{FU, NAL, StapA}

  @frame_prefix <<1::32>>
  @type sequence_number :: 0..65_535

  def_output_pads output: [
                    caps: {H264, stream_format: :byte_stream}
                  ]

  def_input_pads input: [
                   caps: {RTP, payload_type: :dynamic},
                   demand_unit: :buffers
                 ]

  defmodule State do
    @moduledoc false
    defstruct parser_acc: nil
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
    NAL.Header.parse_unit_header(payload)
    ~>> ({:ok, {header, rest}} ->
           case NAL.Header.decode_type(header) do
             :single_nalu ->
               buffer_output(payload, buffer)

             :fu_a ->
               handle_fu(header, rest, buffer, state)

             :stap_a ->
               handle_stap(rest, buffer)
           end)
    ~>> ({:error, reason} ->
           log_malformed_buffer(buffer, reason)
           {{:ok, redemand: :output}, %State{state | parser_acc: nil}})
  end

  @impl true
  def handle_demand(_output_pad, size, :buffers, _ctx, state),
    do: {{:ok, demand: {:input, size}}, state}

  def handle_demand(_, _, :bytes, state), do: {{:error, :not_supported_unit}, state}

  @impl true
  def handle_event(:input, %Discontinuity{} = event, _context, %State{parser_acc: %FU{}} = state),
    do: {{:ok, forward: event}, %State{state | parser_acc: nil}}

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
        {{:ok, redemand: :output}, %State{state | parser_acc: fu}}
    )
  end

  defp handle_stap(data, buffer) do
    with {:ok, result} <- StapA.parse(data) do
      result = Enum.flat_map(result, &action_from_data(&1, buffer))
      {{:ok, result}, %State{}}
    end
  end

  defp buffer_output(data, buffer),
    do: {{:ok, action_from_data(data, buffer)}, %State{}}

  defp action_from_data(data, buffer) do
    data
    |> add_prefix()
    ~> [buffer: {:output, %Buffer{buffer | payload: &1}}]
  end

  defp add_prefix(stream), do: @frame_prefix <> stream

  defp map_state_to_fu(%State{parser_acc: %FU{} = fu}), do: fu
  defp map_state_to_fu(_), do: %FU{}

  defp log_malformed_buffer(%Buffer{metadata: metadata}, reason) do
    %{rtp: %{sequence_number: seq_num}} = metadata

    warn("""
    An error occurred while parsing RTP frame with sequence_number: #{seq_num}
    Reason: #{reason}
    """)
  end
end
