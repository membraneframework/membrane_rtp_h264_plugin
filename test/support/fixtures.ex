defmodule Membrane.Support.Fixtures do
  @moduledoc false
  def get_fixture(name), do: name |> path() |> File.read!()
  def path(fixture_name), do: Path.join([__DIR__, "fixtures", fixture_name])
end
