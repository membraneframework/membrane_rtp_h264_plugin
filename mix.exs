defmodule Membrane.RTP.H264.MixProject do
  use Mix.Project

  @version "0.7.1"
  @github_url "https://github.com/membraneframework/membrane_rtp_h264_plugin"

  def project do
    [
      app: :membrane_rtp_h264_plugin,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: "Membrane RTP payloader and depayloader for H264",
      package: package(),
      name: "Membrane RTP H264 Plugin",
      source_url: @github_url,
      docs: docs(),
      homepage_url: "https://membraneframework.org",
      deps: deps(),
      aliases: [
        credo: "credo --ignore Credo.Check.Refactor.PipeChainStart"
      ]
    ]
  end

  def application do
    [
      extra_applications: [],
      mod: {Membrane.RTP.H264.Plugin.App, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [
        Membrane.RTP.H264
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp deps do
    [
      {:bunch, "~> 1.2"},
      {:membrane_core, "~> 0.8.0"},
      {:membrane_rtp_format, "~> 0.3.0"},
      {:membrane_caps_video_h264, "~> 0.2.0"},
      # Dev
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
