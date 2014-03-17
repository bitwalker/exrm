defmodule Mix.Tasks.Release do
  @moduledoc """
  Build a release for the current mix application.

  ## Examples

    # Build a release using defaults
    mix release
    # Use a specific version of ERTS
    mix release --erts=6.0
    # Use a specific version of Elixir (branch or tag name)
    mix release --elixir=v0.13
    # Pass args to erlexec when running the release
    mix release --erl="-env TZ UTC"
    # Set the verbosity level
    mix release --verbosity=[silent|quiet|normal|verbose]

  You may pass any number of arguments as needed. Make sure you pass arguments
  using `--key=value`, not `--key value`, as the args may be interpreted incorrectly
  otherwise.

  """
  @shortdoc "Build a release for the current mix application."

  use    Mix.Task
  import ExRM.Release.Utils

  @_RELXCONF    "relx.config"
  @_RUNNER      "runner"
  @_SYSCONFIG   "sys.config"
  @_RELEASE_DEF "release_definition.txt"
  @_RELEASES    "{{{RELEASES}}}"
  @_NAME        "{{{PROJECT_NAME}}}"
  @_VERSION     "{{{PROJECT_VERSION}}}"
  @_ERTS_VSN    "{{{ERTS_VERSION}}}"
  @_ERL_OPTS    "{{{ERL_OPTS}}}"
  @_ELIXIR_PATH "{{{ELIXIR_PATH}}}"

  def run(args) do
    # Ensure this isn't an umbrella project
    if Mix.Project.umbrella? do
      raise Mix.Error, message: "Umbrella projects are not currently supported!"
    end
    # Start with a clean slate
    Mix.Tasks.Release.Clean.do_cleanup(:build)
    # Collect release configuration
    config = [ priv_path:  Path.join([__DIR__, "..", "..", "..", "priv"]) |> Path.expand,
               name:       Mix.project |> Keyword.get(:app) |> atom_to_binary,
               version:    Mix.project |> Keyword.get(:version),
               erts:       "6.0",
               erl:        "",
               upgrade?:   false,
               verbosity:  :quiet]
    config
    |> Keyword.merge(args |> parse_args)
    |> prepare_relx
    |> build_project
    |> generate_relx_config
    |> generate_runner
    |> do_release

    info "Your release is ready!"
  end

  defp prepare_relx(config) do
    # Ensure relx has been downloaded
    case fetch_relx do
      :ok ->
        # Continue...
        config
      {:error, message} ->
        error message
        exit(:normal)
    end
  end

  defp build_project(config) do
    # Fetch deps, and compile, using the prepared Elixir binaries
    mix "deps.get",     :prod
    mix "deps.compile", :prod
    mix "compile",      :prod
    # Continue...
    config
  end

  defp generate_relx_config(config) do
    # Get configuration
    priv     = config |> Keyword.get(:priv_path)
    name     = config |> Keyword.get(:name)
    version  = config |> Keyword.get(:version)
    # Get paths
    deffile  = Path.join([priv, "rel", "files", @_RELEASE_DEF])
    source   = Path.join([priv, "rel", @_RELXCONF])
    base     = Path.join(File.cwd!, "rel")
    dest     = Path.join(base, @_RELXCONF)
    # Get relx.config template contents
    relx_config = source |> File.read!
    # Get release definition template contents
    tmpl = deffile |> File.read!
    # Generate release configuration for historical releases
    releases = get_releases(name)
      |> Enum.map(fn {rname, rver} -> tmpl |> replace_release_info(rname, rver) end)
      |> Enum.join
    # Set upgrade flag if this is an upgrade release
    config = case releases do
      "" -> config
      _  -> config |> Keyword.merge [upgrade?: true]
    end
    # Write release configuration
    relx_config = relx_config
      |> String.replace(@_RELEASES, releases)
      |> String.replace(@_ELIXIR_PATH, get_elixir_path() |> Path.join("lib"))
    # Replace placeholders for current release
    relx_config = relx_config |> replace_release_info(name, version)
    # Ensure destination base path exists
    File.mkdir_p!(base)
    # Write relx.config
    File.write!(dest, relx_config)
    # Return the project config after we're done
    config
  end

  defp generate_runner(config) do
    priv      = config |> Keyword.get(:priv_path)
    name      = config |> Keyword.get(:name)
    version   = config |> Keyword.get(:version)
    erts      = config |> Keyword.get(:erts)
    erl_opts  = config |> Keyword.get(:erl)
    runner    = Path.join([priv, "rel", "files", @_RUNNER])
    sysconfig = Path.join([priv, "rel", "files", @_SYSCONFIG])
    base      = Path.join([File.cwd!, "rel", "files"])
    dest      = Path.join(base, @_RUNNER)
    # Ensure destination base path exists
    File.mkdir_p!(base)
    debug "Generating boot script..."
    contents = File.read!(runner)
      |> String.replace(@_NAME, name)
      |> String.replace(@_VERSION, version)
      |> String.replace(@_ERTS_VSN, erts)
      |> String.replace(@_ERL_OPTS, erl_opts)
    File.write!(dest, contents)
    # Copy sys.config
    File.copy!(sysconfig, Path.join(base, @_SYSCONFIG))
    # Make executable
    dest |> chmod("+x")
    # Return the project config after we're done
    config
  end

  defp do_release(config) do
    debug "Generating release..."
    name      = config |> Keyword.get(:name)
    version   = config |> Keyword.get(:version)
    verbosity = config |> Keyword.get(:verbosity)
    upgrade?  = config |> Keyword.get(:upgrade?)
    # Do release
    case relx name, version, verbosity, upgrade? do
      :ok ->
        # Clean up template files
        Mix.Tasks.Release.Clean.do_cleanup(:relfiles)
        # Continue..
        config
      {:error, message} ->
        error message
        exit(:normal)
    end
  end

  defp parse_args(argv) do
    {args, _, _} = OptionParser.parse(argv)
    args |> Enum.map(&parse_arg/1)
  end
  defp parse_arg({:verbosity, verbosity}), do: {:verbosity, binary_to_atom(verbosity)}
  defp parse_arg({_key, _value} = arg),    do: arg

  defp replace_release_info(template, name, version) do
    template
    |> String.replace(@_NAME, name)
    |> String.replace(@_VERSION, version)
  end

end
