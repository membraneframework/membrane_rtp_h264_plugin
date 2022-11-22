defmodule Membrane.RTP.H264.PayloaderPipelineTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Buffer
  alias Membrane.RTP.H264.NAL
  alias Membrane.RTP.H264.StapA
  alias Membrane.Support.PayloaderTestingPipeline
  alias Membrane.Testing.Source

  @max_size 1400

  describe "Payloader in pipeline" do
    test "payloads Fu A" do
      big_unit_size = 10_000
      big_unit = <<1::32, 1, 0::size(big_unit_size)-unit(8)>>

      {:ok, _supervisor_pid, pid} =
        [%Buffer{payload: big_unit, metadata: %{timestamp: 0, h264: %{end_access_unit: true}}}]
        |> Source.output_from_buffers()
        |> PayloaderTestingPipeline.start_pipeline()

      # Membrane.Pipeline.play(pid)
      Membrane.Testing.Pipeline.execute_actions(pid, playback: :playing)

      data_base = 0..div(big_unit_size, @max_size)

      Enum.each(data_base, fn i ->
        assert_sink_buffer(pid, :sink, %Buffer{payload: data, metadata: metadata})

        assert <<f::1, nri::2, fu_type::5, s::1, e::1, r::1, real_type::5, rest::binary>> = data

        assert f == 0
        assert r == 0
        assert nri == 0
        assert NAL.Header.encode_type(:fu_a) == fu_type
        assert real_type == 1
        first..last = data_base

        cond do
          i == first ->
            assert metadata.rtp.marker == false
            assert s == 1
            assert e == 0
            assert rest == <<0::size(@max_size)-unit(8)>>

          i == last ->
            assert metadata.rtp.marker == true
            assert s == 0
            assert e == 1
            last_chunk_size = rem(big_unit_size, @max_size)
            assert rest == <<0::size(last_chunk_size)-unit(8)>>

          true ->
            assert metadata.rtp.marker == false
            assert s == 0
            assert e == 0
            assert rest == <<0::size(@max_size)-unit(8)>>
        end
      end)

      Membrane.Pipeline.terminate(pid, blocking?: true)
    end

    test "payloads Stap A" do
      number_of_packets = 16
      single_size = div(@max_size - 1, number_of_packets) - 2
      single_unit = <<0::size(single_size)-unit(8)>>

      {:ok, _supervisor_pid, pid} =
        %Buffer{
          payload: <<1::32>> <> single_unit,
          metadata: %{timestamp: 0, h264: %{end_access_unit: true}}
        }
        |> List.duplicate(number_of_packets)
        |> Source.output_from_buffers()
        |> PayloaderTestingPipeline.start_pipeline()

      # Membrane.Pipeline.play(pid)
      Membrane.Testing.Pipeline.execute_actions(pid, playback: :playing)

      assert_sink_buffer(pid, :sink, %Buffer{payload: data, metadata: metadata})
      assert metadata.rtp.marker == true
      type = NAL.Header.encode_type(:stap_a)
      assert <<0::1, 0::2, ^type::5, rest::binary>> = data
      assert {:ok, glued} = StapA.parse(rest)
      assert glued == List.duplicate(single_unit, number_of_packets)

      Membrane.Pipeline.terminate(pid, blocking?: true)
    end

    test "payloads single NAL units" do
      number_of_packets = 16

      {:ok, _supervisor_pid, pid} =
        1..number_of_packets
        |> Enum.map(&<<1::32, &1::size(@max_size)-unit(8)>>)
        |> Enum.map(
          &%Buffer{payload: &1, metadata: %{timestamp: 0, h264: %{end_access_unit: true}}}
        )
        |> Source.output_from_buffers()
        |> PayloaderTestingPipeline.start_pipeline()

      # Membrane.Pipeline.play(pid)
      Membrane.Testing.Pipeline.execute_actions(pid, playback: :playing)

      1..number_of_packets
      |> Enum.each(fn i ->
        assert_sink_buffer(pid, :sink, %Buffer{payload: data, metadata: metadata})
        assert metadata.rtp.marker == true
        assert <<i::size(@max_size)-unit(8)>> == data
      end)

      Membrane.Pipeline.terminate(pid, blocking?: true)
    end
  end
end
