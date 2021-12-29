defmodule Membrane.Support.PayloaderTestingPipeline do
  @moduledoc false
  alias Membrane.H264
  alias Membrane.RTP.H264.Payloader
  alias Membrane.Testing
  alias Testing.Pipeline

  @spec start_pipeline(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_pipeline(data) do
    options = %Pipeline.Options{
      elements: [
        source: %Testing.Source{
          output: data,
          caps: %H264{
            width: nil,
            height: nil,
            framerate: nil,
            stream_format: :byte_stream,
            alignment: :nal,
            nalu_in_metadata?: nil,
            profile: nil
          }
        },
        payloader: Payloader,
        sink: %Testing.Sink{}
      ]
    }

    Pipeline.start_link(options)
  end
end
