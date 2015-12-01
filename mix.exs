defmodule ReleaseManager.Mixfile do
  use Mix.Project

  def project do
    [ app: :exrm,
      version: "1.0.0-rc7",
      elixir: "~> 1.0",
      description: description,
      package: package,
      deps: deps,
      docs: docs,
      test_coverage: [tool: Coverex.Task, coveralls: true]]
  end

  def application, do: [
    applications: [:logger, :relx]
  ]

  def deps do
    [{:relx, "~> 3.5.0" },
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.10", only: :dev},
     {:coverex, "~> 1.4", only: :test}]
  end

  defp description do
    """
    Exrm, or Elixir Release Manager, provides mix tasks for building,
    upgrading, and controlling release packages for your application.
    """
  end

  defp package do
    [ files: ["lib", "priv", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: %{ "GitHub": "https://github.com/bitwalker/exrm" } ]
  end

  defp docs do
    [main: "extra-getting-started",
     extras: [
        "docs/Getting Started.md",
        "docs/Release Configuration.md",
        "docs/Deployment.md",
        "docs/Upgrades and Downgrades.md",
        "docs/Common Issues.md",
        "docs/Examples.md"
    ]]
  end

end
