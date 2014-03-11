defmodule Mix.Tasks.Release.Clean do
  @moduledoc """
  Clean up any release-related files.

  ## Examples

    mix release.clean

  """
  @shortdoc "Clean up any release-related files."

  use     Mix.Task
  import  Mix.Tasks.Release, only: [info: 1, success: 1]

  @_MAKEFILE "Makefile"
  @_RELXCONF "relx.config"
  @_RUNNER   "runner"
  @_NAME     "{{{PROJECT_NAME}}}"
  @_VERSION  "{{{PROJECT_VERSION}}}"

  def run(_) do
    do_cleanup
  end

  defp do_cleanup do
    cwd = File.cwd!
    makefile = cwd |> Path.join(@_MAKEFILE)
    relfiles = cwd |> Path.join("rel")
    elixir   = cwd |> Path.join("_elixir")
    rebar    = cwd |> Path.join("rebar")
    relx     = cwd |> Path.join("relx")

    info "Removing release files..."
    if File.exists?(makefile), do: File.rm!(makefile)
    if File.exists?(relfiles), do: File.rm_rf!(relfiles)
    if File.exists?(elixir),   do: File.rm_rf!(elixir)
    if File.exists?(rebar),    do: File.rm!(rebar)
    if File.exists?(relx),     do: File.rm!(relx)
    success "All release files were removed successfully!"
  end

end