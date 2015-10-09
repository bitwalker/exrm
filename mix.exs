defmodule ReleaseManager.Mixfile do
  use Mix.Project

  def project do
    [ app: :exrm,
      version: "0.19.6",
      elixir: "~> 1.0",
      description: description,
      package: package,
      deps: deps,
      docs: docs,
      test_coverage: [tool: Coverex.Task, coveralls: true]]
  end

  def application, do: []

  def deps do
    [{:conform, "~> 0.16.0"},
     {:relx, "~> 3.5.0" },
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.9", only: :dev},
     {:coverex, "~> 1.4.1", only: :test}]
  end

  defp description do
    """
    Exrm, or Elixir Release Manager, provides mix tasks for building, 
    upgrading, and controlling release packages for your application.
    """
  end

  defp package do
    [ files: ["lib", "priv", "mix.exs", "README.md", "LICENSE"],
      contributors: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: %{ "GitHub": "https://github.com/bitwalker/exrm" } ]
  end

  defp docs do
    [main: "getting_started",
     extras: [
        "docs/getting_started.md",
        "docs/release_configuration.md",
        "docs/deployment.md",
        "docs/upgrades_and_downgrades.md",
        "docs/common_issues.md",
        "docs/examples.md"
    ]]
  end

end
