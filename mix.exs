defmodule Membrane.RTP.H264.MixProject do
  use Mix.Project

  @version "0.20.5"
  @github_url "https://github.com/membraneframework/membrane_rtp_h264_plugin"

  def project do
    [
      app: :membrane_rtp_h264_plugin,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # hex
      description: "Membrane RTP payloader and depayloader for H264",
      package: package(),

      # docs
      name: "Membrane RTP H264 Plugin",
      source_url: @github_url,
      docs: docs(),
      homepage_url: "https://membrane.stream",
      aliases: [docs: ["docs", &prepend_llms_links/1]]
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
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membrane.stream"
      }
    ]
  end

  defp deps do
    [
      {:membrane_core, "~> 1.0"},
      {:membrane_h264_format, "~> 0.6.0"},
      {:membrane_rtp_format, "~> 0.11.0"},
      {:bunch, "~> 1.5"},
      # Dev
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling]
    ]

    if System.get_env("CI") == "true" do
      # Store PLTs in cacheable directory for CI
      [plt_local_path: "priv/plts", plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end

  defp prepend_llms_links(_) do
    path = "doc/llms.txt"

    if File.exists?(path) do
      existing = File.read!(path)

      header = "- [Membrane Core](https://hexdocs.pm/membrane_core/llms.txt)\n\n"

      File.write!(path, header <> existing)
    end
  end
end
