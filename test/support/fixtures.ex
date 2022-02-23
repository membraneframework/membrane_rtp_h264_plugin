defmodule Membrane.Support.Fixtures do
  @moduledoc false
  @spec get_fixture(String.t()) :: binary()
  def get_fixture(name), do: name |> path() |> File.read!()

  @spec path(String.t()) :: Path.t()
  def path(fixture_name), do: Path.join([__DIR__, "fixtures", fixture_name])
end
