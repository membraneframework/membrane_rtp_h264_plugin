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
  @prefered_single_size 2000
  @single_max_size 6500
  # @prefered_single_size 8192
  # @single_max_size 16_384
  @max_sequence_number 65_535
  @max_timestamp 4_294_967_296

  @type sequence_number :: 0..65_535

  def_output_pad :output,
    caps: {RTP, payload_type: :dynamic}

  def_input_pad :input,
    caps: {H264, stream_format: :byte_stream},
    demand_unit: :buffers

  defmodule State do
    @moduledoc false
    defstruct [
      :rtp_sequence_number,
      parser_acc: <<>>,
      units_in_acc: 0,
      stap_a_nri: 0,
      stap_a_reserved: 0,
      metadata: %{}
    ]
  end

  def handle_init(_) do
    {:ok, %State{rtp_sequence_number: Enum.random(0..@max_sequence_number)}}
  end

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(
        :input,
        %Buffer{payload: payload, metadata: metadata} = buffer,
        _ctx,
        state
      ) do
    type = get_unit_type(payload)

    with rtp_metadata = Map.get(metadata, :rtp, %{}),
         {{:ok, stap_a_buffer}, state} <- handle_accumulator(type, buffer, state),
         state = update_state_metadata(type, rtp_metadata, state),
         {{:ok, actions}, state} <- handle_unit_type(type, payload, state) |> unify_result do
      {{:ok, stap_a_buffer ++ actions}, state}
    else
      {:ok, state} ->
        rtp_metadata = Map.get(metadata, :rtp, %{timestamp: @max_timestamp})
        state = update_state_metadata(type, rtp_metadata, state)
        handle_unit_type(type, payload, state)
    end
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    IO.puts("demand #{size}")
    {{:ok, demand: {:input, size}}, state}
  end

  def handle_demand(:output, _, :bytes, _ctx, state), do: {{:error, :not_supported_unit}, state}

  @impl true
  def handle_event(:input, event, _context, state), do: {{:ok, forward: event}, state}

  @impl true
  def handle_end_of_stream(:input, _context, state), do: flush_accumulator(state)

  defp get_unit_type(payload) do
    size = byte_size(payload)

    cond do
      size < @single_min_size -> :stap_a
      size < @single_max_size -> :single_nalu
      true -> :fu_a
    end
  end

  defp update_state_metadata(:stap_a, metadata, state) do
    if state.units_in_acc != 0 do
      metadata = Map.put(metadata, :timestamp, min(metadata.timestamp, state.metadata.timestamp))
      %State{state | metadata: metadata}
    else
      %State{state | metadata: metadata}
    end
  end

  defp update_state_metadata(_type, metadata, state), do: %State{state | metadata: metadata}

  defp handle_accumulator(:stap_a, _buffer, state), do: {:ok, state}
  defp handle_accumulator(_type, _buffer, state), do: flush_accumulator(state)

  defp flush_accumulator(state) do
    cond do
      state.parser_acc == <<>> ->
        {:ok, state}

      state.units_in_acc == 1 ->
        state.parser_acc
        |> delete_stap_a_size
        |> action_from_data(state)

      true ->
        state.parser_acc
        |> add_stap_a_header(state)
        |> action_from_data(state)
    end
  end

  defp handle_unit_type(:single_nalu, payload, state) do
    payload
    |> delete_prefix()
    |> action_from_data(state)
    |> redemand()
  end

  defp handle_unit_type(:fu_a, payload, state) do
    payload
    |> delete_prefix
    |> divide_fua_payload(state)
    |> action_from_data(state)
    |> redemand()
  end

  defp handle_unit_type(:stap_a, payload, state) do
    state = update_stap_a_properties(payload, state)

    payload
    |> delete_prefix()
    |> add_stap_a_size
    |> add_to_accumulator(state)
    |> redemand()
  end

  defp unify_result({:ok, state}), do: {{:ok, []}, state}
  defp unify_result(result), do: result

  defp add_to_accumulator(data, state) do
    acc = state.parser_acc <> data

    if byte_size(acc) >= @prefered_single_size do
      state = clear_parser_acc(state)

      acc
      |> add_stap_a_header(state)
      |> action_from_data(state)
    else
      state =
        state
        |> Map.put(:parser_acc, acc)
        |> Map.put(:units_in_acc, state.units_in_acc + 1)

      {:ok, state}
    end
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

  defp redemand(result) do
    with {{:ok, actions}, state} <- result |> unify_result do
      {{:ok, actions ++ [redemand: :output]}, state}
    end
  end

  defp buffer_from_payload(payload, state) do
    state = %State{state | rtp_sequence_number: get_next_sequence_number(state)}

    metadata = Map.put(state.metadata, :sequence_number, state.rtp_sequence_number)

    buffer = %Buffer{
      payload: payload,
      metadata: %{rtp: metadata}
    }

    {:ok, buffer, state}
  end

  defp get_next_sequence_number(state) do
    rem(state.rtp_sequence_number + 1, @max_sequence_number + 1)
  end

  defp delete_prefix(@frame_prefix_longer <> rest), do: rest

  defp delete_prefix(@frame_prefix_shorter <> rest), do: rest

  defp divide_fua_payload(<<head::binary-@prefered_single_size, rest::binary>>, state) do
    with <<r::1, nri::2, type::5, rest_of_head::binary>> <- head do
      payload = add_fu_a_indicator_and_header(rest_of_head, 1, 0, r, nri, type)
      [payload | do_divide_fua_payload(rest, r, nri, type, state)]
    end
  end

  defp do_divide_fua_payload(
         <<head::binary-@prefered_single_size, rest::binary>>,
         r,
         nri,
         type,
         state
       ) do
    payload = add_fu_a_indicator_and_header(head, 0, 0, r, nri, type)
    [payload] ++ do_divide_fua_payload(rest, r, nri, type, state)
  end

  defp do_divide_fua_payload(rest, r, nri, type, _state),
    do: [add_fu_a_indicator_and_header(rest, 0, 1, r, nri, type)]

  defp add_fu_a_indicator_and_header(payload, s, e, r, nri, type),
    do: <<r::1, nri::2, NAL.Header.encode_type(:fu_a)::5, s::1, e::1, 0::1, type::5>> <> payload

  defp add_stap_a_size(<<_nalu_hdr::binary-1, rest::binary>> = data),
    do: <<byte_size(rest)::size(16)>> <> data

  defp delete_stap_a_size(<<_size::size(16), rest::binary>>), do: rest

  defp add_stap_a_header(payload, state),
    do:
      <<state.stap_a_reserved::1, state.stap_a_nri::2, NAL.Header.encode_type(:stap_a)::5>> <>
        payload

  defp clear_parser_acc(state) do
    state
    |> Map.put(:parser_acc, <<>>)
    |> Map.put(:units_in_acc, 0)
    |> Map.put(:stap_a_reserved, 0)
    |> Map.put(:stap_a_nri, 0)
  end

  defp update_stap_a_properties(<<r::1, nri::2, _type::5, _rest::binary()>>, state) do
    state
    |> Map.put(:stap_a_reserved, state.stap_a_reserved && r)
    |> Map.put(:stap_a_nri, min(state.stap_a_nri, nri))
  end
end
