defmodule Membrane.RTP.H264.StapATest do
  use ExUnit.Case
  use Bunch

  alias Membrane.RTP.H264.StapA
  alias Membrane.Support.Formatters.STAPFactory

  describe "Single Time Agregation Packet parser" do
    test "properly decodes nal aggregate" do
      test_data = STAPFactory.sample_data()

      test_data
      |> STAPFactory.binaries_into_stap()
      |> StapA.parse()
      ~> ({:ok, result} -> Enum.zip(result, test_data))
      |> Enum.each(fn {a, b} -> assert a == b end)
    end

    test "returns error when packet is malformed" do
      assert {:error, :packet_malformed} == StapA.parse(<<35_402::16, 0, 0, 0, 0, 0, 0, 1, 1, 2>>)
    end
  end
end
