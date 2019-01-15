defmodule Membrane.Element.RTP.H264.Depayloader do
  @moduledoc """
  Depayloads H264 RTP payloads into H264 NALs.
  """
  use Membrane.Element.Base.Filter
  use Bunch

  @start_code_prefix_one_3bytes <<1::32>>
  @type sequence_number :: 0..65_535

  def_output_pads output: [
                    caps: :any
                  ]

  def_input_pads input: [
                   caps: :any,
                   demand_unit: :buffers
                 ]

  alias Membrane.Element.RTP.H264.NALHeader
  alias NALHeader.PayloadTypeDecoder
  alias Membrane.Element.RTP.H264.{FU, StapA}
  alias Membrane.Buffer

  @impl true
  def handle_process(_pad, %Buffer{payload: payload, metadata: meta} = buffer, _ctx, state) do
    case NALHeader.parse_unit_header(payload) do
      {:error, :malformed_data} ->
        {:ok, %{}}

      {:ok, {header, rest}} ->
        case PayloadTypeDecoder.decode_type(header.type) do
          :rbsp_type ->
            buffer_output(payload, buffer)

          :fu_a ->
            case FU.parse(rest, extract_seq_num(meta), map_state_to_fu(state)) do
              {:ok, data} -> buffer_output(data, buffer)
              {:incomplete, fu} -> {:ok, fu}
              {:error, _} -> {:ok, %{}}
            end

          :stap_a ->
            case StapA.parse(rest) do
              {:ok, data} ->
                data
                |> Enum.flat_map(&action_from_data(&1, buffer))
                ~> {{:ok, &1}, %{}}

              {:error, _} ->
                {:ok, %{}}
            end
        end
    end
  end

  @impl true
  def handle_demand(_output_pad, size, _unit, _ctx, state),
    do: {{:ok, demand: {:input, size}}, state}

  defp extract_seq_num(meta), do: meta ~> (%{rtp: %{sequence_number: seq_num}} -> seq_num)

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
