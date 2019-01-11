defmodule Membrane.Element.RtpH264.Depayloader do
  use Membrane.Element.Base.Filter

  @start_code_prefix_one_3bytes <<1::32>>

  # Doklejać prefix
  # States?
  #  Waiting for fragment
  #  Clear

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
        packetization_type = PayloadTypeDecoder.decode_type(header.type)

        case packetization_type do
          :rbsp_type ->
            buffer_output(rest)

          :fu_a ->
            FU.parse(rest, extract_seq_num(meta), map_state_to_fu(state))
            |> handle_fu_result()

          :stap_a ->
            StapA.parse(rest)
            |> case do
              {:ok, data} -> action_from_data(data)
              {:error, _} -> {:ok, %{}}
            end
        end
    end
  end

  @impl true
  def handle_demand(_output_pad, _size, _unit, _ctx, state) do
    {:ok, state}
  end

  defp extract_seq_num(meta) do
    %{rtp: %{sequence_number: seq_num}} = meta
    seq_num
  end

  defp precede_with_signature(stream), do: @start_code_prefix_one_3bytes <> stream

  defp action_from_data(data) do
    data = precede_with_signature(data)
    [buffer: {:output, data}]
  end

  defp buffer_output(data), do: {{:ok, action_from_data(data)}, %{}}

  defp map_state_to_fu(%FU{} = fu), do: fu
  defp map_state_to_fu(%{}), do: %FU{}

  defp handle_fu_result(result)
  defp handle_fu_result({:ok, data}), do: buffer_output(data)
  defp handle_fu_result({:incomplete, fu}), do: {:ok, fu}
  defp handle_fu_result({:error, _}), do: {:ok, %{}}
end
