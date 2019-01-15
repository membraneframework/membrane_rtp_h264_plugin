defmodule Membrane.Support.DepayloaderTestingPipeline do
  @moduledoc false
  alias Membrane.Testing
  alias Testing.Pipeline
  alias Membrane.Element.RTP.H264.Depayloader

  @spec start_pipeline(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_pipeline(generator) do
    options = %Pipeline.Options{
      elements: [
        source: %Testing.Source{actions_generator: generator},
        depayloader: Depayloader,
        sink: %Testing.Sink{target: self()}
      ]
    }

    Pipeline.start_link(options)
  end
end
