defmodule Membrane.RTP.H264.DepayloaderTest do
  use ExUnit.Case
  use Bunch

  alias Membrane.Buffer
  alias Membrane.RTP.H264.{Depayloader, FU}
  alias Membrane.Support.Formatters.{FUFactory, RBSPNaluFactory, STAPFactory}

  @empty_state %Depayloader.State{}

  describe "Depayloader when processing data" do
    test "passes through packets with type 1..23 (RBSP types)" do
      data = RBSPNaluFactory.sample_nalu()
      buffer = %Buffer{payload: data}

      assert {{:ok, actions}, @empty_state} =
               Depayloader.handle_process(:input, buffer, nil, @empty_state)

      assert {:output, result} = Keyword.fetch!(actions, :buffer)
      assert %Buffer{payload: <<1::32, processed_data::binary()>>} = result
      assert processed_data == data
    end

    test "parses FU-A packets" do
      assert {actions, @empty_state} =
               FUFactory.get_all_fixtures()
               |> Enum.map(&FUFactory.precede_with_fu_nal_header/1)
               ~> (enum -> Enum.zip(enum, 1..Enum.count(enum)))
               |> Enum.map(fn {elem, seq_num} ->
                 %Buffer{payload: elem, metadata: %{rtp: %{sequence_number: seq_num}}}
               end)
               |> Enum.reduce(@empty_state, fn buffer, prev_state ->
                 Depayloader.handle_process(:input, buffer, nil, prev_state)
                 ~> (
                   {{:ok, []}, %Depayloader.State{} = state} -> state
                   {{:ok, actions}, state} -> {actions, state}
                 )
               end)

      assert {:output, %Buffer{payload: data}} = Keyword.fetch!(actions, :buffer)
      assert data == <<1::32, FUFactory.glued_fixtures()::binary()>>
    end

    test "parses STAP-A packets" do
      data = STAPFactory.sample_data()

      buffer = %Buffer{payload: STAPFactory.into_stap_unit(data)}

      assert {{:ok, actions}, _state} =
               Depayloader.handle_process(:input, buffer, nil, @empty_state)

      assert [buffer: {:output, buffers}] = actions

      buffers
      |> Enum.zip(data)
      |> Enum.each(fn {result, original_data} ->
        assert %Buffer{payload: result_data} = result
        assert <<1::32, ^original_data::binary>> = result_data
      end)
    end
  end

  describe "Depayloader when handling events" do
    alias Membrane.Event.Discontinuity

    test "drops current accumulator in case of discontinuity" do
      state = %Depayloader.State{parser_acc: %FU{}}

      {{:ok, actions}, @empty_state} =
        Depayloader.handle_event(:input, %Discontinuity{}, nil, state)

      assert actions == [forward: %Discontinuity{}]
    end

    test "passes through rest of events" do
      assert {{:ok, actions}, @empty_state} =
               Depayloader.handle_event(:input, %Discontinuity{}, nil, @empty_state)

      assert actions == [forward: %Discontinuity{}]
    end
  end

  describe "Depayloader resets internal state in case of error and redemands" do
    test "when parsing Fragmentation Unit" do
      assert {:ok, @empty_state} ==
               %Buffer{
                 metadata: %{rtp: %{sequence_number: 2}},
                 payload:
                   <<92, 1, 184, 105, 243, 121, 62, 233, 29, 109, 103, 237, 76, 39, 197, 20, 67,
                     149, 169, 61, 178, 147, 249, 138, 15, 81, 60, 59, 234, 117, 32, 55, 245, 115,
                     49, 165, 19, 87, 99, 15, 255, 51, 62, 243, 41, 9>>
               }
               ~> Depayloader.handle_process(:input, &1, nil, %Depayloader.State{
                 parser_acc: %FU{}
               })
    end

    test "when parsing Single Time Agregation Unit" do
      assert {:ok, @empty_state} ==
               %Buffer{
                 metadata: %{rtp: %{sequence_number: 2}},
                 payload: <<24>> <> <<35_402::16, 0, 0, 0, 0, 0, 0, 1, 1, 2>>
               }
               ~> Depayloader.handle_process(:input, &1, nil, @empty_state)
    end

    test "when parsing not valid nalu" do
      assert {:ok, @empty_state} ==
               %Buffer{
                 metadata: %{rtp: %{sequence_number: 2}},
                 payload: <<128::8>>
               }
               ~> Depayloader.handle_process(:input, &1, nil, @empty_state)
    end
  end
end
