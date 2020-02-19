defmodule Membrane.Support.PayloaderTestingPipeline do
  @moduledoc false
  alias Membrane.Element.RTP.H264.Payloader
  alias Membrane.Testing
  alias Testing.Pipeline

  @spec start_pipeline(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_pipeline(data) do
    options = %Pipeline.Options{
      elements: [
        source: %Testing.Source{output: data},
        payloader: Payloader,
        sink: %Testing.Sink{}
      ]
    }

    Pipeline.start_link(options)
  end
end
