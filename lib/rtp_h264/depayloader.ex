defmodule Membrane.RTP.H264.Depayloader do
  @moduledoc """
  Depayloads H264 RTP payloads into H264 NAL Units.

  Based on [RFC 6184](https://tools.ietf.org/html/rfc6184).

  Supported types: Single NALU, FU-A, STAP-A.
  """
  use Membrane.Filter

  require Membrane.Logger

  alias Membrane.Buffer
  alias Membrane.Event.Discontinuity
  alias Membrane.H264
  alias Membrane.{RemoteStream, RTP}
  alias Membrane.RTP.H264.{FU, NAL, StapA}

  @frame_prefix <<1::32>>

  def_input_pad :input, caps: RTP, demand_mode: :auto

  def_output_pad :output,
    caps: {RemoteStream, content_format: H264, type: :packetized},
    demand_mode: :auto

  defmodule State do
    @moduledoc false
    defstruct parser_acc: nil
  end

  @impl true
  def handle_init(_opts) do
    {:ok, %State{}}
  end

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    caps = %RemoteStream{content_format: H264, type: :packetized}
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: ""}, _ctx, state) do
    Membrane.Logger.debug("Received empty RTP packet. Ignoring")
    {:ok, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    with {:ok, {header, _payload} = nal} <- NAL.Header.parse_unit_header(buffer.payload),
         unit_type = NAL.Header.decode_type(header),
         {{:ok, actions}, state} <- handle_unit_type(unit_type, nal, buffer, state) do
      {{:ok, actions}, state}
    else
      {:error, reason} ->
        log_malformed_buffer(buffer, reason)
        {:ok, %State{state | parser_acc: nil}}
    end
  end

  @impl true
  def handle_event(:input, %Discontinuity{} = event, _context, %State{parser_acc: %FU{}} = state),
    do: {{:ok, forward: event}, %State{state | parser_acc: nil}}

  @impl true
  def handle_event(pad, event, context, state), do: super(pad, event, context, state)

  defp handle_unit_type(:single_nalu, _nal, buffer, state) do
    buffer_output(buffer.payload, buffer, state)
  end

  defp handle_unit_type(:fu_a, {header, data}, buffer, state) do
    %Buffer{metadata: %{rtp: %{sequence_number: seq_num}}} = buffer

    case FU.parse(data, seq_num, map_state_to_fu(state)) do
      {:ok, {data, type}} ->
        data = NAL.Header.add_header(data, 0, header.nal_ref_idc, type)
        buffer_output(data, buffer, %State{state | parser_acc: nil})

      {:incomplete, fu} ->
        {{:ok, []}, %State{state | parser_acc: fu}}

      {:error, _reason} = error ->
        error
    end
  end

  defp handle_unit_type(:stap_a, {_header, data}, buffer, state) do
    with {:ok, result} <- StapA.parse(data) do
      buffers = Enum.map(result, &%Buffer{buffer | payload: add_prefix(&1)})
      {{:ok, buffer: {:output, buffers}}, state}
    end
  end

  defp buffer_output(data, buffer, state),
    do: {{:ok, action_from_data(data, buffer)}, state}

  defp action_from_data(data, buffer) do
    [buffer: {:output, %Buffer{buffer | payload: add_prefix(data)}}]
  end

  defp add_prefix(data), do: @frame_prefix <> data

  defp map_state_to_fu(%State{parser_acc: %FU{} = fu}), do: fu
  defp map_state_to_fu(_state), do: %FU{}

  defp log_malformed_buffer(packet, reason) do
    Membrane.Logger.warn("""
    An error occurred while parsing H264 RTP payload.
    Reason: #{reason}
    Packet: #{inspect(packet, limit: :infinity)}
    """)
  end
end
