defmodule Membrane.Element.RTP.H264.FUTest do
  use ExUnit.Case
  use Bunch

  alias Membrane.Element.RTP.H264.FU
  alias Membrane.Support.Formatters.FUFactory

  @base_seq_num 4567

  describe "Fragmentation Unit parser" do
    test "parses first packet" do
      packet = FUFactory.first()

      assert {:incomplete, fu} = FU.parse(packet, @base_seq_num, %FU{})
      assert %FU{last_seq_num: @base_seq_num} = fu
    end

    test "parses packet sequence" do
      fixtures = FUFactory.get_all_fixtures()

      result =
        fixtures
        |> Enum.zip(1..Enum.count(fixtures))
        |> Enum.reduce(%FU{}, fn {elem, seq_num}, acc ->
          FU.parse(elem, seq_num, acc)
          ~> ({_command, value} -> value)
        end)

      expected_result = FUFactory.glued_fixtures() ~> (<<_::8, rest::binary()>> -> rest)
      assert result == {expected_result, 1}
    end

    test "returns error when one of non edge packets dropped" do
      fixtures = FUFactory.get_all_fixtures()

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
      assert {:error, :invalid_first_packet} == FU.parse(invalid_first_packet, 2, %FU{})
    end

    test "returns error when header is not valid" do
      assert {:error, :packet_malformed} == FU.parse(<<0::2, 1::1, 1::5>>, 0, %FU{})
    end
  end
end
