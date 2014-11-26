docs_task = "tasks/docs.exs"
if File.exists?(docs_task) do
  Code.eval_file "tasks/docs.exs"
end

defmodule ReleaseManager.Mixfile do
  use Mix.Project

  def project do
    [ app: :exrm,
      version: "0.14.13",
      elixir: ">= 0.15.1 and ~> 1.0.0",
      description: description,
      package: package,
      deps: [{:conform, "~> 0.10.5"}] ]
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
      links: %{ "GitHub": "https://github.com/bitwalker/exrm" } ]
  end

end
