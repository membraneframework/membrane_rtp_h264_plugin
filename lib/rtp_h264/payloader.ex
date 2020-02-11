defmodule Membrane.Element.RTP.H264.Payloader do
  @moduledoc """
  Payloads H264 NAL Units into H264 RTP payloads.
  """

  use Membrane.Filter
  use Membrane.Log

  alias Membrane.Buffer
  alias Membrane.Caps.{RTP, Video.H264}
  alias Membrane.Element.RTP.H264.{FU, NAL, StapA}

  @frame_prefix_shorter <<1::24>>
  @frame_prefix_longer <<1::32>>
  @min_single_size 512
  @preferred_size 1024
  @max_single_size 16_384
  @max_sequence_number 65_535
  @max_timestamp 4_294_967_296

  @typedoc """
  Options that can be passed when creating Payloader.
  Available options are:
  * `min_single_size` - minimal byte size for Single NALU. Units smaller than it will be 
    aggregated in STAP-A payloads. By default it's #{@min_single_size}.
  * `max_single_size` - maximal byte size for Single NALU. Units bigger than it will be 
    fragmented into FU-A payloads. By default it's #{@max_single_size}.
  * `preferred_size` - byte size which will be a target for Payloader. During fragmentation
  into FU-A payloads, every (but last) payload will be of preferred size. During aggregation into
  STAP-A payloads Payloader will send payload if it exceeds preferred size. By default it's 
  #{@preferred_size}.
  """
  @type options_t :: %{
          min_single_size: non_neg_integer() | nil,
          max_single_size: pos_integer() | nil,
          preferred_size: pos_integer() | nil
        }

  def_output_pad :output,
    caps: {RTP, payload_type: :dynamic}

  def_input_pad :input,
    caps: {H264, stream_format: :byte_stream},
    demand_unit: :buffers

  defmodule State do
    @moduledoc false
    defstruct [
      :sequence_number,
      :max_single_size,
      :min_single_size,
      :preferred_size,
      parser_acc: [],
      acc_byte_size: 0,
      stap_a_nri: 0,
      stap_a_reserved: 0,
      metadata: %{timestamp: 4_294_967_296}
    ]
  end

  @spec handle_init(options :: options_t() | nil) :: {:ok, struct()}
  def handle_init(options) do
    options = options || %{}

    {:ok,
     %State{
       sequence_number: Enum.random(0..@max_sequence_number),
       min_single_size: Map.get(options, :min_single_size, @min_single_size),
       max_single_size: Map.get(options, :max_single_size, @max_single_size),
       preferred_size: Map.get(options, :preferred_size, @preferred_size)
     }}
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
    type = get_unit_type(payload, state)

    with rtp_metadata = Map.get(metadata, :rtp, %{}),
         {{:ok, stap_a_buffer}, state} <- handle_accumulator(type, buffer, state),
         state = %State{state | metadata: rtp_metadata},
         {{:ok, actions}, state} <- handle_unit_type(type, payload, state) |> unify_result do
      {{:ok, stap_a_buffer ++ actions}, state}
    else
      {:ok, state} ->
        rtp_metadata = Map.get(metadata, :rtp, %{timestamp: @max_timestamp})
        state = %State{state | metadata: rtp_metadata}
        handle_unit_type(type, payload, state)
    end
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  def handle_demand(:output, _, :bytes, _ctx, state), do: {{:error, :not_supported_unit}, state}

  @impl true
  def handle_event(:input, event, _context, state), do: {{:ok, forward: event}, state}

  @impl true
  def handle_end_of_stream(:input, _context, state), do: flush_accumulator(state)

  defp get_unit_type(payload, state) do
    size = byte_size(payload)

    cond do
      size < state.min_single_size -> :stap_a
      size < state.max_single_size -> :single_nalu
      true -> :fu_a
    end
  end

  defp handle_accumulator(:stap_a, buffer, %State{metadata: %{timestamp: timestamp}} = state) do
    if buffer.metadata.rtp.timestamp == timestamp do
      {:ok, state}
    else
      flush_accumulator(state)
    end
  end

  defp handle_accumulator(_type, _buffer, state), do: flush_accumulator(state)

  defp flush_accumulator(state) do
    acc = state.parser_acc

    cond do
      acc == [] ->
        {:ok, state}

      length(acc) == 1 ->
        state = clear_parser_acc(state)
        acc |> hd |> StapA.delete_size() |> action_from_data(state)

      true ->
        r = state.stap_a_reserved
        nri = state.stap_a_nri
        state = clear_parser_acc(state)

        acc
        |> Enum.reverse()
        |> IO.iodata_to_binary()
        |> NAL.Header.add_header(r, nri, NAL.Header.encode_type(:stap_a))
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
    |> FU.fragmentate(state.preferred_size)
    |> action_from_data(state)
    |> redemand()
  end

  defp handle_unit_type(:stap_a, payload, state) do
    state = update_stap_a_properties(payload, state)

    payload
    |> delete_prefix()
    |> StapA.add_size()
    |> add_to_accumulator(state)
    |> redemand()
  end

  defp unify_result({:ok, state}), do: {{:ok, []}, state}
  defp unify_result(result), do: result

  defp add_to_accumulator(data, state) do
    state = %State{state | parser_acc: [data | state.parser_acc]}
    {:ok, state}
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
    state = increment_sequence_number(state)
    metadata = Map.put(state.metadata, :sequence_number, state.sequence_number)

    buffer = %Buffer{
      payload: payload,
      metadata: %{rtp: metadata}
    }

    {:ok, buffer, state}
  end

  defp increment_sequence_number(state) do
    %State{state | sequence_number: rem(state.sequence_number + 1, @max_sequence_number + 1)}
  end

  defp delete_prefix(@frame_prefix_longer <> rest), do: rest

  defp delete_prefix(@frame_prefix_shorter <> rest), do: rest

  defp clear_parser_acc(state) do
    state
    |> Map.put(:parser_acc, [])
    |> Map.put(:acc_byte_size, 0)
    |> Map.put(:stap_a_reserved, 0)
    |> Map.put(:stap_a_nri, 0)
  end

  defp update_stap_a_properties(<<r::1, nri::2, _type::5, _rest::binary()>> = payload, state) do
    state
    |> Map.put(:acc_byte_size, state.acc_byte_size + byte_size(payload))
    |> Map.put(:stap_a_reserved, state.stap_a_reserved && r)
    |> Map.put(:stap_a_nri, min(state.stap_a_nri, nri))
  end
end
