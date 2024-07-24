defmodule Reportex.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        reportex: [
          applications: [
            xlsx: :permanent
          ],
          cookie: "bUO6#t@&dF9ofL4U6VPJ27b9ZFg#Y3$*Wdf6J%O66QYj1pR8TP"
        ]
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end
end
