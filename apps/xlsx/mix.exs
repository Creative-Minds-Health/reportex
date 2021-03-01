defmodule Xlsx.MixProject do
  use Mix.Project

  def project do
    [
      app: :xlsx,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.12-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Xlsx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
      {:mongodb_driver, "~> 0.6"},
      {:tzdata, "~> 1.1"},
      {:elixlsx, "~> 0.4.2"},
      {:poison, "~> 3.1"},
      {:nodejs, "~> 2.0"},
      {:erlport, "~> 0.10.1"}
    ]
  end
end
