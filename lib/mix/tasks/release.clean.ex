defmodule Mix.Tasks.Release.Clean do
  @moduledoc """
  Clean up any release-related files.

  ## Examples

    mix release.clean       #=> Cleans release
    mix release.clean --rel #=> Cleans release + generated tools
    mix release.clean --all #=> Cleans absolutely everything

  """
  @shortdoc "Clean up any release-related files."

  use     Mix.Task
  import  Mix.Tasks.Release, only: [info: 1, success: 1]

  @_MAKEFILE "Makefile"
  @_RELXCONF "relx.config"
  @_RUNNER   "runner"
  @_NAME     "{{{PROJECT_NAME}}}"
  @_VERSION  "{{{PROJECT_VERSION}}}"

  def run(args) do
    info "Removing release files..."
    cond do
      "--rel" in args ->
        do_cleanup :rel
      "--all" in args ->
        do_cleanup :all
      true ->
        do_cleanup :build
    end
    success "All release files were removed successfully!"
  end

  # Clean release build
  defp do_cleanup(:build) do
    cwd      = File.cwd!
    project  = Mix.project |> Keyword.get(:app) |> atom_to_binary
    release  = cwd |> Path.join("rel") |> Path.join(project)
    if File.exists?(release), do: File.rm_rf!(release)
  end
  # Clean release build + generated tools
  defp do_cleanup(:rel) do
    # Execute build cleanup
    do_cleanup :build

    # Remove generated tools
    cwd = File.cwd!
    makefile = cwd |> Path.join(@_MAKEFILE)
    relfiles = cwd |> Path.join("rel")
    rebar    = cwd |> Path.join("rebar")
    relx     = cwd |> Path.join("relx")
    if File.exists?(relfiles), do: File.rm_rf!(relfiles)
    if File.exists?(rebar),    do: File.rm!(rebar)
    if File.exists?(relx),     do: File.rm!(relx)
    if File.exists?(makefile), do: File.rm!(makefile)
  end
  defp do_cleanup(:all) do
    # Execute other clean tasks
    do_cleanup :build
    do_cleanup :rel

    # Remove local Elixir
    cwd = File.cwd!
    elixir   = cwd |> Path.join("_elixir")
    if File.exists?(elixir),   do: File.rm_rf!(elixir)
  end

end