defmodule Mix.Tasks.Docs do
  @shortdoc "Build documentation for exrm"
  @moduledoc """
  This task automates building the exrm documentation
  site. In the future I plan on it extracting docs
  from the entire codebase and autogenerate pages, but
  currently it does not do that.
  """
  use Mix.Task

  @theme_path "docs/source/_themes/sphinx_rtd_theme"

  def run(args) do
    args = args || []
    System.cmd("grunt", args, [cd: @theme_path |> Path.expand, into: IO.stream(:stdio, :line)])
  end
end
