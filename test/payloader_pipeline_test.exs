defmodule Membrane.RTP.H264.PayloaderPipelineTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Buffer
  alias Membrane.Testing.Source
  alias Membrane.RTP.H264.NAL
  alias Membrane.RTP.H264.StapA
  alias Membrane.Support.PayloaderTestingPipeline

  @max_size 1400

  describe "Payloader in pipeline" do
    test "does not crash when payloading big units" do
      big_unit_size = 10_000
      big_unit = <<1::32, 1, 0::size(big_unit_size)-unit(8)>>

      {:ok, pid} =
        [%Buffer{payload: big_unit, metadata: %{timestamp: 0, h264: %{}}}]
        |> Source.output_from_buffers()
        |> PayloaderTestingPipeline.start_pipeline()

      Membrane.Pipeline.play(pid)

      data_base = 1..div(big_unit_size, @max_size)

      Enum.each(data_base, fn _ ->
        assert_sink_buffer(pid, :sink, %Buffer{payload: data})

        with <<f::1, nri::2, fu_type::5, _s::1, _e::1, r::1, real_type::5, rest::binary()>> <-
               data do
          assert f == 0
          assert r == 0
          assert nri == 0
          assert NAL.Header.encode_type(:fu_a) == fu_type
          assert real_type == 1
          assert rest == <<0::size(@max_size)-unit(8)>>
        end
      end)
    end

    test "does not crash when payloading small units" do
      number_of_packets = 16
      single_size = div(@max_size - 1, number_of_packets) - 2
      single_unit = <<0::size(single_size)-unit(8)>>

      {:ok, pid} =
        %Buffer{payload: <<1::32>> <> single_unit, metadata: %{timestamp: 0, h264: %{}}}
        |> List.duplicate(number_of_packets)
        |> Source.output_from_buffers()
        |> PayloaderTestingPipeline.start_pipeline()

      Membrane.Pipeline.play(pid)

      assert_sink_buffer(pid, :sink, %Buffer{payload: data})
      type = NAL.Header.encode_type(:stap_a)
      assert <<0::1, 0::2, ^type::5, rest::binary()>> = data
      assert {:ok, glued} = StapA.parse(rest)
      assert glued == List.duplicate(single_unit, number_of_packets)
    end

    test "does not crash when parsing payloading units" do
      number_of_packets = 16

      {:ok, pid} =
        1..number_of_packets
        |> Enum.map(&<<1::32, &1::size(@max_size)-unit(8)>>)
        |> Enum.map(&%Buffer{payload: &1, metadata: %{timestamp: 0, h264: %{}}})
        |> Source.output_from_buffers()
        |> PayloaderTestingPipeline.start_pipeline()

      Membrane.Pipeline.play(pid)

      1..number_of_packets
      |> Enum.each(fn i ->
        assert_sink_buffer(pid, :sink, %Buffer{payload: data})

        assert <<i::size(@max_size)-unit(8)>> == data
      end)
    end
  end
end
