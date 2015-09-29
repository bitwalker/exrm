defmodule ReleaseManager.Mixfile do
  use Mix.Project

  def project do
    [ app: :exrm,
      version: "0.19.6",
      elixir: "~> 1.0",
      description: description,
      package: package,
      deps: deps,
      test_coverage: [tool: Coverex.Task, coveralls: true]]
  end

  def application, do: []

  def deps do
    [{:relx, "~> 3.5.0" },
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

end
