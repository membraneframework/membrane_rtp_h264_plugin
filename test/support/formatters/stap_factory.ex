defmodule Membrane.Support.Formatters.STAPFactory do
  @moduledoc false
  @spec sample_data() :: [binary()]
  def sample_data do
    Enum.map(1..10, &<<&1>>)
  end

  @spec binaries_into_stap([binary()]) :: binary()
  def binaries_into_stap(binaries) do
    binaries
    |> into_aggregation_units()
    |> Enum.reduce(&(&2 <> &1))
  end

  @spec sample_stap_header() :: <<_::8>>
  def sample_stap_header, do: <<0::3, 24::5>>

  @spec into_stap_unit([binary()]) :: binary()
  def into_stap_unit(data), do: sample_stap_header() <> binaries_into_stap(data)

  # STAP type a
  @spec into_aggregation_units([binary()]) :: [binary()]
  def into_aggregation_units(binaries), do: Enum.map(binaries, &<<byte_size(&1)::16, &1::binary>>)

  @spec example_nalu_hdr() :: <<_::8>>
  def example_nalu_hdr, do: <<0::1, 2::2, 1::5>>
end
