defmodule ReleaseManager.Mixfile do
  use Mix.Project

  def project do
    [ app: :exrm,
      version: "0.5.0",
      elixir: "~> 0.13.1",
      description: description,
      package: package,
      deps: [] ]
  end

  def application, do: []

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
      links: [ { "GitHub", "https://github.com/bitwalker/exrm" } ] ]
  end

end
