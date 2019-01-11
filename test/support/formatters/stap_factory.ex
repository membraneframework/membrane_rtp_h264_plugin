defmodule StapFactory do
  def binaries_into_stap(binaries) do
    binaries
    |> into_a_nalus()
    |> Enum.reverse()
    |> Enum.reduce(&Kernel.<>/2)
  end

  # STAP type a
  def into_a_nalus(binaries),
    do:
      Enum.map(binaries, fn binary ->
        <<byte_size(binary)::16>> <> example_nalu_hdr() <> binary
      end)

  def example_nalu_hdr(), do: <<0::1, 2::2, 1::5>>
end
