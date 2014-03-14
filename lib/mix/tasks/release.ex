defmodule Mix.Tasks.Release do
  @moduledoc """
  Build a release for the current mix application.

  ## Examples

    mix release

  """
  @shortdoc "Build a release for the current mix application."

  use    Mix.Task
  import ExRM.Release.Utils

  @_RELXCONF "relx.config"
  @_RUNNER   "runner"
  @_NAME     "{{{PROJECT_NAME}}}"
  @_VERSION  "{{{PROJECT_VERSION}}}"

  def run(_) do
    # Ensure this isn't an umbrella project
    if Mix.Project.umbrella? do
      raise Mix.Error, message: "Umbrella projects are not currently supported!"
    end
    # Collect release configuration
    config = [ priv_path:  Path.join([__DIR__, "..", "..", "..", "priv"]) |> Path.expand,
               name:       Mix.project |> Keyword.get(:app) |> atom_to_binary,
               version:    Mix.project |> Keyword.get(:version),
               verbosity:  :quiet]
    config
    |> prepare_elixir
    |> prepare_relx
    |> generate_relx_config
    |> generate_runner
    |> do_release

    info "Your release is ready!"
  end

  defp prepare_elixir(config) do
    # Ensure Elixir has been cloned, and the right branch is checked out
    fetch_elixir :default
    # Ensure Elixir is built
    build_elixir
    # Continue...
    config
  end

  defp prepare_relx(config) do
    # Ensure relx has been downloaded
    fetch_relx
    # Continue...
    config
  end

  defp generate_relx_config([priv_path: priv, name: name, version: version, verbosity: _] = config) do
    debug "Generating relx.config"
    source = Path.join([priv, "rel", @_RELXCONF])
    base   = Path.join(File.cwd!, "rel")
    dest   = Path.join(base, @_RELXCONF)
    # Ensure destination base path exists
    File.mkdir_p!(base)
    case File.exists?(dest) do
      # If the config has already been generated, skip generation
      true ->
        # Return the project config after we're done
        config
      # Otherwise, read in relx.config, replace placeholders, and write to the destination in the project root
      _ ->
        contents = File.read!(source) 
          |> String.replace(@_NAME, name)
          |> String.replace(@_VERSION, version)
        File.write!(dest, contents)
        # Return the project config after we're done
        config
    end
  end

  defp generate_runner([priv_path: priv, name: name, version: version, verbosity: _] = config) do
    debug "Generating runner..."
    source = Path.join([priv, "rel", "files", @_RUNNER])
    base   = Path.join([File.cwd!, "rel", "files"])
    dest   = Path.join(base, @_RUNNER)
    # Ensure destination base path exists
    File.mkdir_p!(base)
    case File.exists?(dest) do
      # If the runner has already been generated, skip generation
      true ->
        # Return the project config after we're done
        config
      # Otherwise, read in the runner, replace placeholders, and write to the destination in the project root
      _ ->
        contents = File.read!(source)
          |> String.replace(@_NAME, name)
          |> String.replace(@_VERSION, version)
        File.write!(dest, contents)
        # Make executable
        dest |> chmod("+x")
        # Return the project config after we're done
        config
    end
  end

  defp do_release([priv_path: _, name: name, version: version, verbosity: verbosity] = config) do
    debug "Constructing release..."
    relx name, version, verbosity
    config
  end

end
