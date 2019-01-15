defmodule Membrane.Element.RTP.H264.FU.HeaderTest do
  use ExUnit.Case
  alias Membrane.Element.RTP.H264.FU.Header

  describe "Fragmentation Unit Header parser" do
    test "returns error when invalid data is being parsed" do
      invalid_data = <<1::1, 1::1, 0::1, 1::5>>
      assert {:error, :packet_malformed} == Header.parse(invalid_data)
    end

    test "returns parsed data for valid packets" do
      # First packet, middle packet, end packet
      combinations = [{1, 0}, {0, 0}, {0, 1}]

      combinations
      |> Enum.map(fn {starting, ending} ->
        <<starting::1, ending::1, 0::1, 1::5, 4343::128>>
      end)
      |> Enum.map(&Header.parse/1)
      |> Enum.zip(combinations)
      |> Enum.each(fn {result, {starting, ending}} ->
        assert {:ok, {%Header{start_bit: r_starting, end_bit: r_ending}, _}} = result
        assert starting == 1 == r_starting
        assert ending == 1 == r_ending
      end)
    end

    test "does not allow 1 in must be zero place" do
      assert {:error, :packet_malformed} == Header.parse(<<0::2, 1::1, 1::5>>)
    end
  end
end
