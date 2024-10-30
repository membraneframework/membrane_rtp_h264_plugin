defmodule Membrane.RTP.H264.FUTest do
  use ExUnit.Case
  use Bunch

  alias Membrane.RTP.H264.FU
  alias Membrane.Support.Formatters.FUFactory

  describe "Fragmentation Unit parser" do
    test "parses first packet" do
      packet = FUFactory.first()

      assert {:incomplete, _fu} = FU.parse(packet, %FU{})
    end

    test "parses packet sequence" do
      fixtures = FUFactory.get_all_fixtures()

      result =
        fixtures
        |> Enum.reduce(%FU{}, fn elem, acc ->
          FU.parse(elem, acc)
          ~> ({_command, value} -> value)
        end)

      expected_result = FUFactory.glued_fixtures() ~> (<<_header::8, rest::binary>> -> rest)
      assert result == {expected_result, 1}
    end

    test "returns error when first packet is not starting packet" do
      invalid_first_packet = <<0::5, 3::3>>
      assert {:error, :invalid_first_packet} == FU.parse(invalid_first_packet, %FU{})
    end

    test "returns error when header is not valid" do
      assert {:error, :packet_malformed} == FU.parse(<<0::2, 1::1, 1::5>>, %FU{})
    end
  end
end
