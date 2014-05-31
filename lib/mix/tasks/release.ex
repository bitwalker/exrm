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
  import Kernel, except: [reraise: 2]
  import ReleaseManager.Utils
  alias  ReleaseManager.Config

  @_RELXCONF    "relx.config"
  @_BOOT_FILE   "boot"
  @_NODETOOL    "nodetool"
  @_SYSCONFIG   "sys.config"
  @_RELEASE_DEF "release_definition.txt"
  @_RELEASES    "{{{RELEASES}}}"
  @_NAME        "{{{PROJECT_NAME}}}"
  @_VERSION     "{{{PROJECT_VERSION}}}"
  @_ERTS_VSN    "{{{ERTS_VERSION}}}"
  @_ERL_OPTS    "{{{ERL_OPTS}}}"
  @_LIB_DIRS    "{{{LIB_DIRS}}}"

  def run(args) do
    if Mix.Project.umbrella? do
      config = [build_path: Mix.Project.build_path, umbrella?: true]
      for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
        Mix.Project.in_project(app, opts[:path], config, fn _ -> do_run(args) end)
      end
    else
      do_run(args)
    end
  end

  defp do_run(args) do
    # Start with a clean slate
    Mix.Tasks.Release.Clean.do_cleanup(:build)
    # Collect release configuration
    config = parse_args(args)

    config
    |> build_project
    |> generate_relx_config
    |> generate_sys_config
    |> generate_boot_script
    |> execute_before_hooks
    |> do_release
    |> generate_nodetool
    |> execute_after_hooks

    info "The release for #{config.name}-#{config.version} is ready!"
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
    elixir_path = get_elixir_path() |> Path.join("lib") |> String.to_char_list
    lib_dirs = case Mix.Project.config |> Keyword.get(:umbrella?, false) do
      true ->
        [ elixir_path,
          '../_build/prod',
          '../#{Mix.Project.config |> Keyword.get(:deps_path) |> String.to_char_list}' ]
      _ ->
        [ elixir_path,
          '../_build/prod' ]
    end
    # Write release configuration
    relx_config = relx_config
      |> String.replace(@_RELEASES, releases)
      |> String.replace(@_LIB_DIRS, :io_lib.fwrite('~p.\n\n', [{:lib_dirs, lib_dirs}]) |> List.to_string)
    # Replace placeholders for current release
    relx_config = relx_config |> replace_release_info(name, version)
    # Ensure destination base path exists
    dest |> Path.dirname |> File.mkdir_p!
    # Write relx.config
    File.write!(dest, relx_config)
    # Return the project config after we're done
    config
  end

  defp generate_sys_config(config) do
    default_sysconfig = rel_file_source_path @_SYSCONFIG
    user_sysconfig    = rel_dest_path @_SYSCONFIG
    dest              = rel_file_dest_path   @_SYSCONFIG

    debug "Generating sys.config..."
    # Read in current project config
    project_conf = Mix.Tasks.Loadconfig.load
    # Merge project config with either the user-provided config, or the default sys.config we provide.
    # If a sys.config is provided by the user, it will take precedence over project config. If the
    # default sys.config is used, the project config will take precedence instead.
    merged = case user_sysconfig |> File.exists? do
      true -> 
        # User-provided
        case user_sysconfig |> String.to_char_list |> :file.consult do
          {:ok, []}                                  -> project_conf
          {:ok, [user_conf]} when is_list(user_conf) -> Mix.Config.merge(project_conf, user_conf)
          {:ok, [user_conf]}                         -> Mix.Config.merge(project_conf, [user_conf])
          {:error, {line, type, msg}} ->
            error "Unable to parse sys.config: Line #{line}, #{type} - #{msg}"
            exit(:normal)
          {:error, reason} ->
            error "Unable to access sys.config #{reason}"
            exit(:normal)
        end
      _ ->
        # Default
        case default_sysconfig |> String.to_char_list |> :file.consult do
          {:ok, [default_conf]} ->
            Mix.Config.merge(default_conf, project_conf)
          {:error, {line, type, msg}} ->
            error "Unable to parse default sys.config: Line #{line}, #{type} - #{msg}"
            exit(:normal)
          {:error, reason} ->
            error "Unable to access default sys.config #{reason}"
            exit(:normal)
        end
    end
    # Ensure parent directory exists prior to writing
    File.mkdir_p!(dest |> Path.dirname)
    # Write the config to disk
    dest |> write_term(merged)
    # Continue..
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
    # Continue..
    config
  end

  defp execute_before_hooks(%Config{} = config) do
    plugins = ReleaseManager.Plugin.load_all
    Enum.reduce plugins, config, fn plugin, conf ->
      try do
        # Handle the case where a child plugin does not return the configuration
        case plugin.before_release(conf) do
          %Config{} = result -> result
          _                  -> conf
        end
      rescue
        exception ->
          stacktrace = System.stacktrace
          error "Failed to execute before_release hook for #{plugin}!"
          reraise exception, stacktrace
      end
    end
  end

  defp execute_after_hooks(%Config{} = config) do
    plugins = ReleaseManager.Plugin.load_all
    Enum.reduce plugins, config, fn plugin, conf ->
      try do
        # Handle the case where a child plugin does not return the configuration
        case plugin.after_release(conf) do
          %Config{} = result -> result
          _                  -> conf
        end
      rescue
        exception ->
          stacktrace = System.stacktrace
          error "Failed to execute after_release hook for #{plugin}!"
          reraise exception, stacktrace
      end
    end
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

  defp generate_nodetool(%Config{name: name, version: version} = config) do
    nodetool = rel_file_source_path @_NODETOOL
    dest     = rel_dest_path [name, "bin", @_NODETOOL]
    erts     = "erts-#{:erlang.system_info(:version) |> iodata_to_binary}"
    debug "Generating nodetool..."
    # Copy
    File.cp! nodetool, dest
    # Make executable
    dest |> chmod("+x")
    # Extract release package
    tarball = rel_dest_path [name, "#{name}-#{version}.tar.gz"]
    tmp_dir = rel_dest_path [name, "#{name}-#{version}"]
    :erl_tar.extract('#{tarball}', [{:cwd, '#{tmp_dir}'}, :compressed])
    # Update nodetool
    extracted_nodetool = Path.join([tmp_dir, "bin", @_NODETOOL])
    File.rm! extracted_nodetool
    File.cp! nodetool, extracted_nodetool
    # Re-package release
    :ok = :erl_tar.create(
      '#{tarball}',
      [
        {'lib', '#{Path.join(tmp_dir, "lib")}'},
        {'releases', '#{Path.join(tmp_dir, "releases")}'},
        {'bin', '#{Path.join(tmp_dir, "bin")}'},
        {'#{erts}', '#{Path.join(tmp_dir, erts)}'}
      ],
      [:compressed]
    )
    File.rm_rf! tmp_dir
    # Continue..
    config
  end

  defp parse_args(argv) do
    {args, _, _} = OptionParser.parse(argv)
    defaults = %Config{
      name:    Mix.Project.config |> Keyword.get(:app) |> atom_to_binary,
      version: Mix.Project.config |> Keyword.get(:version),
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
