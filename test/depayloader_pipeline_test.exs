defmodule Membrane.Element.RTP.H264.DepayloaderPipelineTest do
  use ExUnit.Case
  use Bunch

  alias Membrane.Buffer
  alias Membrane.Event.EndOfStream
  alias Membrane.Support.DepayloaderTestingPipeline
  alias Membrane.Support.Formatters.{FUFactory, STAPFactory}

  describe "Depayloader in a pipeline" do
    test "does not crash when parsing staps" do
      STAPFactory.sample_data()
      |> Enum.chunk_every(2)
      |> Enum.map(&STAPFactory.into_stap_unit/1)
      |> Enum.map(&%Membrane.Buffer{payload: &1})
      |> generator_from_data()
      |> DepayloaderTestingPipeline.start_pipeline()
      ~> ({:ok, pipeline} -> Membrane.Pipeline.play(pipeline))

      STAPFactory.sample_data()
      |> Enum.each(fn elem ->
        assert_receive buffer, 5000
        assert %Buffer{payload: payload} = buffer
        assert <<1::32, hdr::binary-size(1), ^elem::binary()>> = payload
        assert hdr == STAPFactory.example_nalu_hdr()
      end)
    end

    test "does not crash when parsing fu" do
      glued_data = FUFactory.glued_fixtures()
      data_base = 1..10

      data_base
      |> Enum.flat_map(fn _ -> FUFactory.get_all_fixtures() end)
      |> Enum.map(fn binary -> <<0::1, 2::2, 28::5>> <> binary end)
      ~> (list -> Enum.zip(list, 1..Enum.count(list)))
      |> Enum.map(fn {data, seq_num} -> into_rtp_buffer(data, seq_num) end)
      |> generator_from_data()
      |> DepayloaderTestingPipeline.start_pipeline()
      ~> ({:ok, pid} -> Membrane.Pipeline.play(pid))

      Enum.each(data_base, fn _ ->
        assert_receive %Buffer{payload: data}
        assert <<1::32, ^glued_data::binary()>> = data
      end)
    end
  end

  def generator_from_data(data) do
    actions = Enum.map(data, fn element -> {:buffer, {:output, element}} end)

    fn cnt, size ->
      if(cnt != 0, do: cnt, else: actions)
      |> Enum.split(size)
      ~>> ({to_send, []} -> {to_send ++ [{:event, {:output, %EndOfStream{}}}], []})
    end
  end

  def into_rtp_buffer(data, seq_num),
    do: %Buffer{payload: data, metadata: %{rtp: %{sequence_number: seq_num}}}
end
