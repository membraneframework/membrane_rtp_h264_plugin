defmodule Membrane.Support.Formatters.FUFactory do
  @moduledoc false
  use Bunch

  alias Membrane.Support.Fixtures

  @max_fixtures 5

  @spec glued_fixtures() :: binary()
  def glued_fixtures do
    get_all_fixtures()
    |> Enum.reduce(<<>>, fn <<_header::8, data::binary>>, acc -> acc <> data end)
    ~> (<<0::1, 2::2, 1::5>> <> &1)
  end

  @spec get_all_fixtures() :: [binary()]
  def get_all_fixtures, do: 1..@max_fixtures |> Enum.map(&get_fixture/1)
  @spec first() :: binary()
  def first, do: get_fixture(1)
  @spec last() :: binary()
  def last, do: get_fixture(@max_fixtures)

  @spec precede_with_fu_nal_header(binary()) :: binary
  def precede_with_fu_nal_header(data) when is_binary(data), do: <<0::1, 2::2, 28::5>> <> data

  defp fixture_name(which), do: "fu_nal_#{which}_#{@max_fixtures}.bin"
  defp get_fixture(which), do: which |> fixture_name() |> Fixtures.get_fixture()
end
