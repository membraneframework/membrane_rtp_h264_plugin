defmodule Membrane.RTP.H264.MixProject do
  use Mix.Project

  @version "0.12.0"
  @github_url "https://github.com/membraneframework/membrane_rtp_h264_plugin"

  def project do
    [
      app: :membrane_rtp_h264_plugin,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: "Membrane RTP payloader and depayloader for H264",
      package: package(),
      name: "Membrane RTP H264 Plugin",
      source_url: @github_url,
      docs: docs(),
      homepage_url: "https://membraneframework.org",
      deps: deps()
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
      formatters: ["HTML"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [
        Membrane.RTP.H264
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp deps do
    [
      {:membrane_core, "~> 0.10.0"},
      {:membrane_rtp_format, "~> 0.4.0"},
      {:membrane_h264_format, "~> 0.3.0"},
      {:bunch, "~> 1.3"},
      # Dev
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:credo, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
