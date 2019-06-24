defmodule Membrane.Element.RTP.H264.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane-element-rtp-h264"

  def project do
    [
      app: :membrane_element_rtp_h264,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: "Membrane Multimedia Framework (RTP H264 Element)",
      package: package(),
      name: "Membrane Element: H264",
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
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      },
      nest_modules_by_prefix: [
        Membrane.Element.RTP.H264
      ]
    ]
  end

  defp deps do
    [
      {:membrane_core,
       github: "membraneframework/membrane-core", branch: "new-testing-api", override: true},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
      {:bunch, "~> 1.0"},
      {:membrane_caps_rtp, github: "membraneframework/membrane-caps-rtp"},
      {:membrane_caps_video_h264, "~> 0.1"},
      {:membrane_loggers, "~> 0.2"},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false}
    ]
  end
end
