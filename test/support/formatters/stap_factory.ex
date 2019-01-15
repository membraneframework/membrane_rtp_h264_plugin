defmodule Membrane.Support.Formatters.STAPFactory do
  def sample_data() do
    1..10
    |> Enum.map(&<<&1::8>>)
  end

  def binaries_into_stap(binaries) do
    binaries
    |> into_a_nalus()
    |> Enum.reverse()
    |> Enum.reduce(&Kernel.<>/2)
  end

  def sample_stap_header, do: <<0::3, 24::5>>
  def into_stap_unit(data), do: sample_stap_header() <> binaries_into_stap(data)

  # STAP type a
  def into_a_nalus(binaries),
    do:
      Enum.map(binaries, fn binary ->
        <<byte_size(binary)::16>> <> example_nalu_hdr() <> binary
      end)

  def example_nalu_hdr(), do: <<0::1, 2::2, 1::5>>
end
