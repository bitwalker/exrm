defmodule Mix.Tasks.Release do
  @moduledoc """
  Build a release for the current mix application.

  ## Examples

    # Build a release using defaults
    mix release
    # Pass args to erlexec when running the release
    mix release --erl="-env TZ UTC"
    # Enable dev mode. Make changes, compile using MIX_ENV=prod
    # and execute your release again to pick up the changes
    mix release --dev
    # Set the verbosity level
    mix release --verbosity=[silent|quiet|normal|verbose]

  You may pass any number of arguments as needed. Make sure you pass arguments
  using `--key=value`, not `--key value`, as the args may be interpreted incorrectly
  otherwise.

  """
  @shortdoc "Build a release for the current mix application."

  use    Mix.Task
  import ReleaseManager.Utils

  @_RELXCONF    "relx.config"
  @_BOOT_FILE   "boot"
  @_SYSCONFIG   "sys.config"
  @_RELEASE_DEF "release_definition.txt"
  @_RELEASES    "{{{RELEASES}}}"
  @_NAME        "{{{PROJECT_NAME}}}"
  @_VERSION     "{{{PROJECT_VERSION}}}"
  @_ERTS_VSN    "{{{ERTS_VERSION}}}"
  @_ERL_OPTS    "{{{ERL_OPTS}}}"
  @_ELIXIR_PATH "{{{ELIXIR_PATH}}}"

  defmodule Config do
    @moduledoc """
    Configuration for the release task
    """
    defstruct name:      "",
              version:   "",
              dev:       false,
              erl:       "",
              upgrade?:  false,
              verbosity: :quiet
  end

  def run(args) do
    # Ensure this isn't an umbrella project
    if Mix.Project.umbrella? do
      raise Mix.Error, message: "Umbrella projects are not currently supported!"
    end
    # Start with a clean slate
    Mix.Tasks.Release.Clean.do_cleanup(:build)
    # Collect release configuration
    parse_args(args)
    |> build_project
    |> generate_relx_config
    |> generate_sys_config
    |> generate_boot_script
    |> do_release

    info "Your release is ready!"
  end

  defp build_project(%Config{verbosity: verbosity} = config) do
    # Fetch deps, and compile, using the prepared Elixir binaries
    cond do
      verbosity == :verbose ->
        mix "deps.get",     :prod, :verbose
        mix "compile",      :prod, :verbose
      true ->
        mix "deps.get",     :prod
        mix "compile",      :prod
    end
    # Continue...
    config
  end

  defp generate_relx_config(%Config{name: name, version: version} = config) do
    # Get paths
    rel_def  = rel_file_source_path @_RELEASE_DEF
    source   = rel_source_path @_RELXCONF
    dest     = rel_dest_path @_RELXCONF
    # Get relx.config template contents
    relx_config = source |> File.read!
    # Get release definition template contents
    tmpl = rel_def |> File.read!
    # Generate release configuration for historical releases
    releases = get_releases(name)
      |> Enum.map(fn {rname, rver} -> tmpl |> replace_release_info(rname, rver) end)
      |> Enum.join
    # Set upgrade flag if this is an upgrade release
    config = case releases do
      "" -> config
      _  -> %{config | :upgrade? => true}
    end
    # Write release configuration
    relx_config = relx_config
      |> String.replace(@_RELEASES, releases)
      |> String.replace(@_ELIXIR_PATH, get_elixir_path() |> Path.join("lib"))
    # Replace placeholders for current release
    relx_config = relx_config |> replace_release_info(name, version)
    # Ensure destination base path exists
    dest |> Path.dirname |> File.mkdir_p!
    # Write relx.config
    File.write!(dest, relx_config)
    # Return the project config after we're done
    config
  end

  defp generate_sys_config(%Config{name: name, version: version} = config) do
    sysconfig = rel_file_source_path @_SYSCONFIG
    dest      = rel_file_dest_path   @_SYSCONFIG
    debug "Generating sys.config..."
    # Copy default sys.config only if user hasn't provided their own
    File.mkdir_p!(dest |> Path.dirname)
    case dest |> File.exists? do
      true -> :ok
      _    -> File.cp!(sysconfig, dest)
    end
    config
  end

  defp generate_boot_script(%Config{name: name, version: version, erl: erl_opts} = config) do
    erts = :erlang.system_info(:version) |> iodata_to_binary
    boot = rel_file_source_path @_BOOT_FILE
    dest = rel_file_dest_path   @_BOOT_FILE
    # Ensure destination base path exists
    debug "Generating boot script..."
    contents = File.read!(boot)
      |> String.replace(@_NAME, name)
      |> String.replace(@_VERSION, version)
      |> String.replace(@_ERTS_VSN, erts)
      |> String.replace(@_ERL_OPTS, erl_opts)
    File.write!(dest, contents)
    # Make executable
    dest |> chmod("+x")
    # Return the project config after we're done
    config
  end

  defp do_release(%Config{name: name, version: version, verbosity: verbosity, upgrade?: upgrade?, dev: dev_mode?} = config) do
    debug "Generating release..."
    # If this is an upgrade release, generate an appup
    if upgrade? do
      # Change mix env for appup generation
      with_env :prod do
        # Generate appup
        app      = name |> binary_to_atom
        v1       = get_last_release(name)
        v1_path  = rel_dest_path [name, "lib", "#{name}-#{v1}"]
        v2_path  = Mix.Project.config |> Mix.Project.compile_path |> String.replace("/ebin", "")
        own_path = rel_dest_path "#{name}.appup"
        # Look for user's own .appup file before generating one
        case own_path |> File.exists? do
          true ->
            # Copy it to ebin
            case File.cp(own_path, Path.join([v2_path, "/ebin", "#{name}.appup"])) do
              :ok ->
                info "Using custom .appup located in rel/#{name}.appup"
              {:error, reason} ->
                error "Unable to copy custom .appup file: #{reason}"
                exit(:normal)
            end
          _ ->
            # No custom .appup found, proceed with autogeneration
            case ReleaseManager.Appups.make(app, v1, version, v1_path, v2_path) do
              {:ok, _}         ->
                info "Generated .appup for #{name} #{v1} -> #{version}"
              {:error, reason} ->
                error "Appup generation failed with #{reason}"
                exit(:normal)
            end
        end
      end
    end
    # Do release
    case relx name, version, verbosity, upgrade?, dev_mode? do
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
    defaults = %Config{
      name:    Mix.project |> Keyword.get(:app) |> atom_to_binary,
      version: Mix.project |> Keyword.get(:version),
    }
    Enum.reduce args, defaults, fn arg, config ->
      case arg do
        {:verbosity, verbosity} ->
          %{config | :verbosity => binary_to_atom(verbosity)}
        {key, value} ->
          Map.put(config, key, value)
      end
    end
  end

  defp replace_release_info(template, name, version) do
    template
    |> String.replace(@_NAME, name)
    |> String.replace(@_VERSION, version)
  end

end
