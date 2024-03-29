defmodule Membrane.Support.PayloaderTestingPipeline do
  @moduledoc false

  import Membrane.ChildrenSpec

  alias Membrane.H264
  alias Membrane.RTP.H264.Payloader
  alias Membrane.Testing
  alias Testing.Pipeline

  @spec start_pipeline(any()) :: pid()
  def start_pipeline(data) do
    structure = [
      child(:source, %Testing.Source{
        output: data,
        stream_format: %H264{
          width: nil,
          height: nil,
          framerate: nil,
          alignment: :nalu,
          nalu_in_metadata?: nil,
          profile: nil
        }
      })
      |> child(:payloader, Payloader)
      |> child(:sink, Testing.Sink)
    ]

    Pipeline.start_link_supervised!(spec: structure)
  end
end
