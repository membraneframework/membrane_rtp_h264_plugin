defmodule Membrane.Element.RTP.H264.Depayloader do
  use Membrane.Element.Base.Filter
  use Bunch

  @start_code_prefix_one_3bytes <<1::32>>

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
  def handle_process(_pad, %Buffer{payload: payload, metadata: meta}, _ctx, state) do
    case NALHeader.parse_unit_header(payload) do
      {:error, :malformed_data} ->
        {:ok, %{}}

      {:ok, {header, rest}} ->
        case PayloadTypeDecoder.decode_type(header.type) do
          :rbsp_type ->
            buffer_output(payload)

          :fu_a ->
            FU.parse(rest, extract_seq_num(meta), map_state_to_fu(state))
            |> handle_fu_result()

          :stap_a ->
            case StapA.parse(rest) do
              {:ok, data} -> {{:ok, Enum.flat_map(data, &action_from_data/1)}, %{}}
              {:error, _} -> {:ok, %{}}
            end
        end
    end
  end

  @impl true
  def handle_demand(_output_pad, _size, _unit, _ctx, state) do
    {:ok, state}
  end

  defp extract_seq_num(meta), do: meta ~> (%{rtp: %{sequence_number: seq_num}} -> seq_num)

  defp precede_with_signature(stream), do: @start_code_prefix_one_3bytes <> stream

  defp action_from_data(data) do
    precede_with_signature(data)
    ~> [buffer: {:output, &1}]
  end

  defp buffer_output(data), do: {{:ok, action_from_data(data)}, %{}}

  defp map_state_to_fu(%FU{} = fu), do: fu
  defp map_state_to_fu(%{}), do: %FU{}

  defp handle_fu_result(result)
  defp handle_fu_result({:ok, data}), do: buffer_output(data)
  defp handle_fu_result({:incomplete, fu}), do: {:ok, fu}
  defp handle_fu_result({:error, _}), do: {:ok, %{}}
end
