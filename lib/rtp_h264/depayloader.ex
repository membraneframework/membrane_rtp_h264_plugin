defmodule Membrane.Element.RTP.H264.Depayloader do
  @moduledoc """
  Depayloads H264 RTP payloads into H264 NAL Units.
  """
  use Membrane.Element.Base.Filter
  use Bunch

  alias Membrane.Caps.{RTP, Video.H264}

  @start_code_prefix_one_3bytes <<1::32>>
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

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {:ok, state}
  end

  @impl true
  def handle_process(_pad, %Buffer{payload: payload} = buffer, _ctx, state) do
    case NALHeader.parse_unit_header(payload) do
      {:error, :malformed_data} ->
        {:ok, %{}}

      {:ok, {header, rest}} ->
        case PayloadTypeDecoder.decode_type(header.type) do
          :rbsp_type ->
            buffer_output(payload, buffer)

          :fu_a ->
            handle_fu(header, rest, buffer, state)

          :stap_a ->
            handle_stap(rest, buffer)
        end
    end
  end

  @impl true
  def handle_demand(_output_pad, size, _unit, _ctx, state),
    do: {{:ok, demand: {:input, size}}, state}

  defp handle_fu(header, data, %Buffer{metadata: metadata} = buffer, state) do
    %{rtp: %{sequence_number: seq_num}} = metadata

    case FU.parse(data, seq_num, map_state_to_fu(state)) do
      {:ok, {data, type}} ->
        is_damaged = if(header.forbidden_zero, do: 1, else: 0)
        header = <<is_damaged::1, header.nal_ref_idc::2, type::5>>
        data = header <> data
        buffer_output(data, buffer)

      {:incomplete, fu} ->
        {:ok, fu}

      {:error, _} ->
        {:ok, %{}}
    end
  end

  defp handle_stap(data, buffer) do
    case StapA.parse(data) do
      {:ok, result} ->
        result
        |> Enum.flat_map(&action_from_data(&1, buffer))
        ~> {{:ok, &1}, %{}}

      {:error, _} ->
        {:ok, %{}}
    end
  end

  defp precede_with_signature(stream), do: @start_code_prefix_one_3bytes <> stream

  defp action_from_data(data, buffer) do
    data
    |> precede_with_signature()
    ~> [buffer: {:output, %Buffer{buffer | payload: &1}}]
  end

  defp buffer_output(data, buffer), do: {{:ok, action_from_data(data, buffer)}, %{}}

  defp map_state_to_fu(%FU{} = fu), do: fu
  defp map_state_to_fu(_), do: %FU{}
end
