defmodule Membrane.Element.RTP.H264.Payloader do
  @moduledoc """
  Payloads H264 NAL Units into H264 RTP payloads.
  """

  use Membrane.Filter
  use Membrane.Log

  alias Membrane.Buffer
  alias Membrane.Caps.{RTP, Video.H264}
  alias Membrane.Element.RTP.H264.NAL

  @frame_prefix_shorter <<1::24>>
  @frame_prefix_longer <<1::32>>
  @single_min_size 1024
  @single_max_size 16384
  @fu_to_single_size 8192
  @max_sequence_number 65_535

  @type sequence_number :: 0..65_535

  def_output_pad :output,
    caps: {RTP, payload_type: :dynamic}

  def_input_pad :input,
    caps: {H264, stream_format: :byte_stream},
    demand_unit: :buffers

  defmodule State do
    @moduledoc false
    defstruct [:rtp_sequence_number]
  end

  def handle_init(_) do
    {:ok, %State{rtp_sequence_number: Enum.random(0..@max_sequence_number)}}
  end

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: payload}, _ctx, state) do
    type = get_unit_type(payload)
    handle_unit_type(type, payload, state)
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state),
    do: {{:ok, demand: {:input, size}}, state}

  def handle_demand(:output, _, :bytes, _ctx, state), do: {{:error, :not_supported_unit}, state}

  @impl true
  def handle_event(:input, event, _context, state), do: {{:ok, forward: event}, state}

  defp get_unit_type(payload) do
    size = byte_size(payload)

    cond do
      size < @single_min_size -> :stap_a
      size < @single_max_size -> :single_nalu
      true -> :fu_a
    end
  end

  defp get_next_sequence_number(state) do
    rem(state.rtp_sequence_number + 1, @max_sequence_number + 1)
  end

  defp handle_unit_type(:single_nalu, payload, state) do
    data = delete_prefix(payload)

    action_from_data(data, state)
  end

  defp handle_unit_type(:fu_a, payload, state) do
    data =
      payload
      |> delete_prefix
      |> divide_fua_payload(state)

    action_from_data(data, state)
  end

  defp action_from_data(data, state) when is_list(data),
    do: actions_from_data(data, [], state)

  defp action_from_data(payload, state) do
    {:ok, buffer, state} = buffer_from_payload(payload, state)
    {{:ok, [buffer: {:output, buffer}]}, state}
  end

  defp actions_from_data([payload | rest], acc, state) do
    {:ok, buffer, state} = buffer_from_payload(payload, state)
    actions_from_data(rest, [buffer | acc], state)
  end

  defp actions_from_data([], acc, state) do
    {{:ok, [buffer: {:output, Enum.reverse(acc)}]}, state}
  end

  defp buffer_from_payload(payload, state) do
    state = %State{rtp_sequence_number: get_next_sequence_number(state)}

    buffer = %Buffer{
      payload: payload,
      metadata: %{rtp: %{sequence_number: state.rtp_sequence_number}}
    }

    {:ok, buffer, state}
  end

  defp delete_prefix(@frame_prefix_longer <> rest), do: rest

  defp delete_prefix(@frame_prefix_shorter <> rest), do: rest

  defp add_stap_a_size(<<_nalu_hdr::binary-1, rest::binary>> = data),
    do: <<byte_size(rest)::size(16)>> <> data

  defp divide_fua_payload(<<head::binary-@fu_to_single_size, rest::binary>>, state) do
    with <<_reserved::1, nri::2, type::5, rest_of_head::binary>> <- head do
      payload = add_fu_a_indicator_and_header(rest_of_head, 1, 0, nri, type)
      [payload | do_divide_fua_payload(rest, nri, type, state)]
    end
  end

  defp do_divide_fua_payload(<<head::binary-@fu_to_single_size, rest::binary>>, nri, type, state) do
    payload = add_fu_a_indicator_and_header(head, 0, 0, nri, type)
    [payload] ++ do_divide_fua_payload(rest, nri, type, state)
  end

  defp do_divide_fua_payload(rest, nri, type, _state),
    do: [add_fu_a_indicator_and_header(rest, 0, 1, nri, type)]

  defp add_fu_a_indicator_and_header(payload, s, e, nri, type),
    do: <<0::1, nri::2, NAL.Header.encode_type(:fu_a)::5, s::1, e::1, 0::1, type::5>> <> payload
end
