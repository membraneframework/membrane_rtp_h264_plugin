defmodule Membrane.Element.RTP.H264.FU.TestFactory do
  @max_fixtures 5

  @spec glued_fixtures() :: binary()
  def glued_fixtures,
    do: Enum.reduce(get_all_fixtures(), <<>>, fn <<_::8, data::binary>>, acc -> acc <> data end)

  @spec get_all_fixtures() :: [binary()]
  def get_all_fixtures(), do: 1..@max_fixtures |> Enum.map(&get_fixture/1)
  @spec first() :: binary()
  def first(), do: get_fixture(1)
  @spec last() :: binary()
  def last(), do: get_fixture(@max_fixtures)
  defp get_fixture(which), do: which |> fixture_name() |> path() |> File.read!()
  defp fixture_name(which), do: "fu_nal_#{which}_#{@max_fixtures}.bin"
  defp path(fixture_name), do: __DIR__ |> Path.join("../fixtures") |> Path.join(fixture_name)
end
