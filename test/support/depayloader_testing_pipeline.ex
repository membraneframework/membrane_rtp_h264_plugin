defmodule Membrane.Support.DepayloaderTestingPipeline do
  @moduledoc false

  import Membrane.ChildrenSpec

  alias Membrane.RTP.H264.Depayloader
  alias Membrane.{RTP, Testing}
  alias Testing.Pipeline

  @spec start_pipeline(any()) :: :ignore | {:error, any()} | {:ok, pid(), pid()}
  def start_pipeline(data) do
    structure = [
      child(:source, %Testing.Source{output: data, stream_format: %RTP{}})
      |> child(:depayloader, Depayloader)
      |> child(:sink, Testing.Sink)
    ]

    Pipeline.start_link_supervised(structure: structure)
  end
end
