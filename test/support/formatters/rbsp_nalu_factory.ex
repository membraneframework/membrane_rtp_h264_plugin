defmodule Membrane.Support.Formatters.RBSPNaluFactory do
  alias Membrane.Support.Fixtures
  def sample_nalu, do: Fixtures.get_fixture("no_processing_nal.bin")
end
