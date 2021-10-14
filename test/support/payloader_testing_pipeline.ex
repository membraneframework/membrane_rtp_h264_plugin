defmodule Membrane.Support.PayloaderTestingPipeline do
  @moduledoc false
  alias Membrane.RTP.H264.Payloader
  alias Membrane.Caps.Video.H264
  alias Membrane.Testing
  alias Testing.Pipeline

  @spec start_pipeline(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_pipeline(data) do
    options = %Pipeline.Options{
      elements: [
        source: %Testing.Source{
          output: data,
          caps: %H264{
            width: 600,
            height: 400,
            framerate: {30, 1},
            profile: :baseline,
            stream_format: :byte_stream,
            alignment: :nal
          }
        },
        payloader: Payloader,
        sink: %Testing.Sink{}
      ]
    }

    Pipeline.start_link(options)
  end
end
