defmodule Membrane.RTP.H264.DepayloaderPipelineTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Buffer
  alias Membrane.Testing.Source
  alias Membrane.Support.{DepayloaderTestingPipeline, Helper}
  alias Membrane.Support.Formatters.{FUFactory, STAPFactory}

  describe "Depayloader in a pipeline" do
    test "does not crash when parsing staps" do
      {:ok, pid} =
        STAPFactory.sample_data()
        |> Enum.chunk_every(2)
        |> Enum.map(&STAPFactory.into_stap_unit/1)
        |> Enum.map(&%Membrane.Buffer{payload: &1})
        |> Source.output_from_buffers()
        |> DepayloaderTestingPipeline.start_pipeline()

      Membrane.Pipeline.play(pid)

      STAPFactory.sample_data()
      |> Enum.each(fn elem ->
        assert_sink_buffer(pid, :sink, buffer)
        assert %Buffer{payload: payload} = buffer
        assert <<1::32, hdr::binary-size(1), ^elem::binary()>> = payload
        assert hdr == STAPFactory.example_nalu_hdr()
      end)
    end

    test "does not crash when parsing fu" do
      glued_data = FUFactory.glued_fixtures()
      data_base = 1..10

      {:ok, pid} =
        data_base
        |> Enum.flat_map(fn _ -> FUFactory.get_all_fixtures() end)
        |> Enum.map(fn binary -> <<0::1, 2::2, 28::5>> <> binary end)
        |> Enum.with_index()
        |> Enum.map(fn {data, seq_num} -> Helper.into_rtp_buffer(data, seq_num) end)
        |> Source.output_from_buffers()
        |> DepayloaderTestingPipeline.start_pipeline()

      Membrane.Pipeline.play(pid)

      Enum.each(data_base, fn _ ->
        assert_sink_buffer(pid, :sink, %Buffer{payload: data})
        assert <<1::32, ^glued_data::binary()>> = data
      end)
    end
  end
end
