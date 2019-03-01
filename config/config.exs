use Mix.Config

config :membrane_core, Membrane.Logger,
  loggers: [
    %{
      module: Membrane.Loggers.Console,
      id: :console,
      level: :info,
      options: [],
      tags: [:all]
    }
  ],
  level: :info
