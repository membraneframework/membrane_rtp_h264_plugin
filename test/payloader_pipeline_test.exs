defmodule Membrane.Element.RTP.H264.PayloaderPipelineTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Buffer
  alias Membrane.Testing.Source
  alias Membrane.Element.RTP.H264.NAL
  alias Membrane.Element.RTP.H264.StapA
  alias Membrane.Support.{Helper, PayloaderTestingPipeline}

  @big_size 16_384
  @preferred_size 1024
  @small_size 512

  describe "Payloader in pipeline" do
    test "does not crash when payloading big units" do
      big_unit_size = @big_size * 8
      rest_size = @preferred_size * 8

      {:ok, pid} =
        (<<1::32>> <> <<1::8>> <> <<0::size(big_unit_size)>>)
        |> Helper.into_rtp_buffer(0)
        |> List.wrap()
        |> Source.output_from_buffers()
        |> PayloaderTestingPipeline.start_pipeline()

      Membrane.Pipeline.play(pid)

      data_base = 1..div(@big_size, @preferred_size)

      Enum.each(data_base, fn _ ->
        assert_sink_buffer(pid, :sink, %Buffer{payload: data})

        with <<f::1, nri::2, fu_type::5, _s::1, _e::1, r::1, real_type::5, rest::binary()>> <-
               data do
          assert f == 0
          assert r == 0
          assert nri == 0
          assert NAL.Header.encode_type(:fu_a) == fu_type
          assert real_type == 1
          assert rest == <<0::size(rest_size)>>
        end
      end)
    end

    test "does not crash when payloading small units" do
      number_of_packets = 16
      single_size = div(@small_size, number_of_packets) * 8
      single_unit = <<1::8>> <> <<0::size(single_size)>>

      {:ok, pid} =
        (<<1::32>> <> single_unit)
        |> List.duplicate(number_of_packets)
        |> Enum.with_index()
        |> Enum.map(fn {data, seq_num} -> Helper.into_rtp_buffer(data, seq_num) end)
        |> Source.output_from_buffers()
        |> PayloaderTestingPipeline.start_pipeline()

      Membrane.Pipeline.play(pid)

      assert_sink_buffer(pid, :sink, %Buffer{payload: data})

      type = NAL.Header.encode_type(:stap_a)
      assert <<0::1, 0::2, ^type::5, rest::binary()>> = data
      assert {:ok, glued} = StapA.parse(rest)
      assert ^glued = List.duplicate(single_unit, number_of_packets)
    end

    test "does not crash when parsing payloading units" do
      number_of_packets = 16
      single_size = @preferred_size * 8

      {:ok, pid} =
        1..number_of_packets
        |> Enum.map(fn i -> <<1::32>> <> <<1::8>> <> <<i::size(single_size)>> end)
        |> Enum.with_index()
        |> Enum.map(fn {data, seq_num} -> Helper.into_rtp_buffer(data, seq_num) end)
        |> Source.output_from_buffers()
        |> PayloaderTestingPipeline.start_pipeline()

      Membrane.Pipeline.play(pid)

      1..number_of_packets
      |> Enum.each(fn i ->
        assert_sink_buffer(pid, :sink, %Buffer{payload: data})

        assert <<0::1, 0::2, 1::5, ^i::size(single_size)>> = data
      end)
    end
  end
end
