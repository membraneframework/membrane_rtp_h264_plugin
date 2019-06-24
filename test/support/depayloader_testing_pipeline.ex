defmodule Membrane.Support.DepayloaderTestingPipeline do
  @moduledoc false
  alias Membrane.Element.RTP.H264.Depayloader
  alias Membrane.Testing
  alias Testing.Pipeline

  @spec start_pipeline(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_pipeline(data) do
    options = %Pipeline.Options{
      elements: [
        source: %Testing.Source{output: data},
        depayloader: Depayloader,
        sink: %Testing.Sink{}
      ]
    }

    Pipeline.start_link(options)
  end
end
