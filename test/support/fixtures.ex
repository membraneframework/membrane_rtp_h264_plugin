defmodule Membrane.Support.Fixtures do
  def get_fixture(name), do: name |> path() |> File.read!()
  def path(fixture_name), do: __DIR__ |> Path.join("fixtures") |> Path.join(fixture_name)
end
