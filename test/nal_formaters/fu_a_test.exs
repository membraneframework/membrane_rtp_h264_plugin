defmodule Membrane.Element.RTP.H264.FUTest do
  use ExUnit.Case
  use Bunch

  alias Membrane.Element.RTP.H264.FU.TestFactory
  alias Membrane.Element.RTP.H264.FU

  @base_seq_num 4567

  describe "Fragmentation Unit parser" do
    test "parses first packet" do
      packet = TestFactory.first()

      assert {:incomplete, fu} = FU.parse(packet, @base_seq_num)
      assert %FU{data: [{hdr, @base_seq_num, _}]} = fu

      assert hdr == %Membrane.Element.RTP.H264.FU.Header{
               end_bit: 0,
               reserved: false,
               start_bit: 1,
               type: 1
             }
    end

    test "parses packet sequence" do
      fixtures = TestFactory.get_all_fixtures()

      result =
        fixtures
        |> Enum.zip(1..Enum.count(fixtures))
        |> Enum.reduce(%FU{}, fn {elem, seq_num}, acc ->
          FU.parse(elem, seq_num, acc)
          ~>> ({_command, value} -> value)
        end)

      assert result == TestFactory.glued_fixtures()
    end

    test "returns error when one of non edge packets dropped" do
      fixtures = TestFactory.get_all_fixtures()

      assert {:error, :missing_packet} ==
               fixtures
               |> Enum.zip([0, 1, 3, 4, 5])
               |> Enum.reduce(%FU{}, fn {elem, seq_num}, acc ->
                 FU.parse(elem, seq_num, acc)
                 ~>> ({command, fu} when command in [:incomplete, :ok] -> fu)
               end)
    end

    test "returns error when first packet is not starting packet" do
      invalid_first_packet = <<0::5, 3::3>>
      assert {:error, :invalid_first_packet} == FU.parse(invalid_first_packet, 2)
    end
  end
end
