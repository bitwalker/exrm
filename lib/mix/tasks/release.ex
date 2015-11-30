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

      # Do not ask for confirmation to skip missing applications warning
      mix release --no-confirm-missing

  You may pass any number of arguments as needed. Make sure you pass arguments
  using `--key=value`, not `--key value`, as the args may be interpreted incorrectly
  otherwise.

  """
  @shortdoc "Build a release for the current mix application"

  use    Mix.Task
  import ReleaseManager.Utils
  alias  ReleaseManager.Utils
  alias  ReleaseManager.Utils.Logger
  alias  ReleaseManager.Config
  alias  ReleaseManager.Deps

  @_RELXCONF    "relx.config"
  @_BOOT_FILE   "boot"
  @_NODETOOL    "nodetool"
  @_SYSCONFIG   "sys.config"
  @_VMARGS      "vm.args"
  @_RELEASE_DEF "release_definition.txt"
  @_RELEASES    "{{{RELEASES}}}"
  @_NAME        "{{{PROJECT_NAME}}}"
  @_VERSION     "{{{PROJECT_VERSION}}}"
  @_ERTS_VSN    "{{{ERTS_VERSION}}}"
  @_ERL_OPTS    "{{{ERL_OPTS}}}"
  @_LIB_DIRS    "{{{LIB_DIRS}}}"

  def run(args) do
    {:ok, _} = Logger.start_link

    Mix.Project.compile(args)

    if Mix.Project.umbrella? do
      config = [umbrella?: true]
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
    Logger.notice "Building release with MIX_ENV=#{config.env}."
    # Begin release pipeline
    config
    |> check_applications(args)
    |> generate_relx_config
    |> generate_sys_config
    |> generate_vm_args
    |> generate_boot_script
    |> execute_before_hooks
    |> do_release
    |> generate_nodetool
    |> generate_install_escript
    |> execute_after_hooks
    |> update_release_package
    |> execute_package_hooks

    Logger.info "The release for #{config.name}-#{config.version} is ready!"
    Logger.info "You can boot a console running your release with `$ rel/#{config.name}/bin/#{config.name} console`"
  end

  defp check_applications(%Config{} = config, args) do
    case Deps.print_missing_applications(ignore: [:exrm]) do
      ""     -> config
      output ->
        IO.puts IO.ANSI.yellow
        IO.puts "You have dependencies (direct/transitive) which are not in :applications!"
        IO.puts "The following apps should to be added to :applications in mix.exs:\n#{output}#{IO.ANSI.reset}\n"
        case "--no-confirm-missing" in args do
          true  ->
            config
          false ->
            msg    = IO.ANSI.yellow <> "Continue anyway? Your release may not work as expected if these dependencies are required!"
            answer = IO.gets(msg <> " [Yn]: ") |> String.rstrip(?\n)
            IO.puts IO.ANSI.reset
            case answer =~ ~r/^(Y(es)?)?$/i do
              true  -> config
              false -> abort!
            end
        end
    end
  end

  defp generate_relx_config(%Config{name: name, version: version, env: env} = config) do
    Logger.debug "Generating relx configuration..."
    # Get paths
    rel_def  = rel_file_source_path @_RELEASE_DEF
    source   = rel_source_path @_RELXCONF
    dest     = rel_file_dest_path @_RELXCONF
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
    elixir_paths = get_elixir_lib_paths |> Enum.map(&String.to_char_list/1)
    lib_dirs = case Mix.Project.config |> Keyword.get(:umbrella?, false) do
      true ->
        [ '#{"_build/#{env}" |> Path.expand}',
          '#{Mix.Project.config |> Keyword.get(:deps_path) |> Path.expand}' | elixir_paths ]
      _ ->
        [ '#{"_build/#{env}" |> Path.expand}' | elixir_paths ]
    end
    # Build release configuration
    relx_config = relx_config
      |> String.replace(@_RELEASES, releases)
      |> String.replace(@_LIB_DIRS, :io_lib.fwrite('~p.\n\n', [{:lib_dirs, lib_dirs}]) |> List.to_string)
    # Replace placeholders for current release
    relx_config = relx_config |> replace_release_info(name, version)
    # Read config as Erlang terms
    relx_config = Utils.string_to_terms(relx_config)
    # Merge user provided relx.config
    user_config_path = rel_dest_path @_RELXCONF
    merged = case user_config_path |> File.exists? do
      true  ->
        Logger.debug "Merging custom relx configuration from #{user_config_path |> Path.relative_to_cwd}..."
        case Utils.read_terms(user_config_path) do
          []                                      -> relx_config
          [{_, _}|_] = user_config                -> Utils.merge(relx_config, user_config)
          [user_config] when is_list(user_config) -> Utils.merge(relx_config, user_config)
          [user_config]                           -> Utils.merge(relx_config, [user_config])
        end
      _ ->
        relx_config
    end
    # Save relx config for use later
    config = %{config | :relx_config => merged}
    # Ensure destination base path exists
    dest |> Path.dirname |> File.mkdir_p!
    # Persist relx.config
    Utils.write_terms(dest, merged)
    # Return the project config after we're done
    config
  end

  defp generate_sys_config(%Config{env: env} = config) do
    default_sysconfig = rel_file_source_path @_SYSCONFIG
    user_sysconfig    = rel_dest_path @_SYSCONFIG
    dest              = rel_file_dest_path   @_SYSCONFIG

    Logger.debug "Generating sys.config..."
    # Read in current project config
    project_conf = load_config(env)
    # Merge project config with either the user-provided config, or the default sys.config we provide.
    # If a sys.config is provided by the user, it will take precedence over project config. If the
    # default sys.config is used, the project config will take precedence instead.
    merged = case user_sysconfig |> File.exists? do
      true ->
        Logger.debug "Merging custom sys.config from #{user_sysconfig |> Path.relative_to_cwd}..."
        # User-provided
        case user_sysconfig |> Utils.read_terms do
          []                                  -> project_conf
          [user_conf] when is_list(user_conf) -> Mix.Config.merge(project_conf, user_conf)
          [user_conf]                         -> Mix.Config.merge(project_conf, [user_conf])
        end
      _ ->
        # Default
        [default_conf] = default_sysconfig |> Utils.read_terms
        Mix.Config.merge(default_conf, project_conf)
    end
    # Ensure parent directory exists prior to writing
    File.mkdir_p!(dest |> Path.dirname)
    # Write the config to disk
    dest |> Utils.write_term(merged)
    # Continue..
    config
  end

  defp generate_vm_args(%Config{version: version} = config) do
    vmargs_path = Utils.rel_dest_path("vm.args")
    if vmargs_path |> File.exists? do
      Logger.debug "Generating vm.args..."
      relx_config_path = Utils.rel_file_dest_path("relx.config")
      # Read in relx.config
      relx_config = relx_config_path |> Utils.read_terms
      # Update configuration to add new overlay for vm.args
      overlays = [overlay: [
        {:copy, vmargs_path |> String.to_char_list, 'releases/#{version}/vm.args'}
      ]]
      updated = Utils.merge(relx_config, overlays)
      # Persist relx.config
      Utils.write_terms(relx_config_path, updated)
    end
    # Continue..
    config
  end

  defp generate_boot_script(%Config{name: name, version: version, erl: erl_opts} = config) do
    erts    = extract_erts_version(config)
    boot    = rel_file_source_path @_BOOT_FILE
    winboot = rel_file_source_path "#{@_BOOT_FILE}.bat"
    dest    = rel_file_dest_path   @_BOOT_FILE
    windest = rel_file_dest_path   "#{@_BOOT_FILE}.bat"
    shim    = rel_file_source_path "boot_shim"
    winshim = rel_file_source_path "boot_shim.bat"
    shim_dest    = rel_file_dest_path "boot_shim"
    winshim_dest = rel_file_dest_path "boot_shim.bat"

    Logger.debug "Generating boot script..."

    [{boot, dest}, {winboot, windest}, {shim, shim_dest}, {winshim, winshim_dest}]
    |> Enum.each(fn {infile, outfile} ->
      contents = File.read!(infile)
        |> String.replace(@_NAME, name)
        |> String.replace(@_VERSION, version)
        |> String.replace(@_ERTS_VSN, erts)
        |> String.replace(@_ERL_OPTS, erl_opts)
      File.write!(outfile, contents)
      # Make executable
      outfile |> chmod(0o700)
    end)

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
          Logger.error "Failed to execute before_release hook for #{plugin}!"
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
          Logger.error "Failed to execute after_release hook for #{plugin}!"
          reraise exception, stacktrace
      end
    end
  end

  defp execute_package_hooks(%Config{} = config) do
    plugins = ReleaseManager.Plugin.load_all
    Enum.reduce plugins, config, fn plugin, conf ->
      try do
        # Handle the case where a child plugin does not return the configuration
        case plugin.after_package(conf) do
          %Config{} = result -> result
          _                  -> conf
        end
      rescue
        exception ->
          stacktrace = System.stacktrace
          Logger.error "Failed to execute after_package hook for #{plugin}!"
          reraise exception, stacktrace
      end
    end
  end

  defp do_release(%Config{name: name, version: version, verbosity: verbosity, upgrade?: upgrade?, dev: dev_mode?, env: env} = config) do
    Logger.debug "Generating release..."
    # If this is an upgrade release, generate an appup
    if upgrade? do
      # Change mix env for appup generation
      with_env env, fn ->
        # Generate appup
        app      = name |> String.to_atom
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
                Logger.info "Using custom .appup located in rel/#{name}.appup"
              {:error, reason} ->
                Logger.error "Unable to copy custom .appup file: #{reason}"
                abort!
            end
          _ ->
            # No custom .appup found, proceed with autogeneration
            case ReleaseManager.Appups.make(app, v1, version, v1_path, v2_path) do
              {:ok, _}         ->
                Logger.info "Generated .appup for #{name} #{v1} -> #{version}"
              {:error, reason} ->
                Logger.error "Appup generation failed with #{reason}"
                abort!
            end
        end
      end
    end
    # Do release
    try do
      case relx name, version, verbosity, upgrade?, dev_mode? do
        :ok ->
          # Clean up template files
          Mix.Tasks.Release.Clean.do_cleanup(:relfiles)
          # Continue..
          config
        {:error, message} ->
          Logger.error message
          abort!
      end
    catch
      err ->
        Logger.error "#{IO.inspect err}"
        Logger.error "Failed to build release package! Try running with `--verbosity=verbose` to see debugging info!"
        abort!
    end
  end

  defp generate_nodetool(%Config{name: name} = config) do
    Logger.debug "Generating nodetool..."
    nodetool = rel_file_source_path @_NODETOOL
    dest     = rel_dest_path [name, "bin", @_NODETOOL]
    # Copy
    File.cp! nodetool, dest
    # Make executable
    dest |> chmod(0o700)
    # Continue..
    config
  end

  defp generate_install_escript(%Config{name: name} = config) do
    escript = rel_file_source_path "install_upgrade.escript"
    dest    = rel_dest_path [name, "bin", "install_upgrade.escript"]
    File.cp! escript, dest
    config
  end

  defp update_release_package(%Config{dev: true} = config), do: config
  defp update_release_package(%Config{name: name, version: version, relx_config: relx_config} = config) do
    Logger.debug "Packaging release..."
    # Delete original release package
    tarball = rel_dest_path [name, "#{name}-#{version}.tar.gz"]
    File.rm! tarball
    # Make sure we have a start.boot file for upgrades/downgrades
    source_boot = rel_dest_path([name, "releases", version, "#{name}.boot"])
    dest_boot   = rel_dest_path([name, "releases", version, "start.boot"])
    File.cp! source_boot, dest_boot
    # Get include_erts value from relx_config
    include_erts = Keyword.get(relx_config, :include_erts, true)
    erts         = "erts-#{extract_erts_version(config)}"
    extras = case include_erts do
      false -> []
      _     -> [{'#{erts}', '#{rel_dest_path([name, erts])}'}]
    end
    # Re-package release with modifications
    file_list = File.ls!(rel_dest_path(name))
      |> Enum.reject(fn n -> n in [erts, "tmp"] end)
      |> Enum.map(fn
           "releases" -> [Path.join("releases", "RELEASES"),
                          Path.join("releases", "start_erl.data") |
                          File.ls!(rel_dest_path([name, "releases", version]))
                          |> Enum.reject(&(String.ends_with?(&1, ".tar.gz")))
                          |> Enum.map(fn n -> Path.join(["releases", version, n]) end)]
           "lib"      -> File.ls!(rel_dest_path([name, "lib"]))
                         |> Enum.reject(fn n -> String.starts_with?(n, "#{name}-") && !String.ends_with?(n, "-#{version}") end)
                         |> Enum.map(fn n -> Path.join("lib", n) end)
           n          -> [n]
         end)
      |> List.flatten
      |> Enum.map(&({'#{&1}', '#{rel_dest_path([name, &1])}'}))
      |> Enum.concat(extras)

    # Create archive
    release_tarball = rel_dest_path([name, "releases", version, "#{name}.tar.gz"])
    :ok = :erl_tar.create(
      '#{tarball}.tmp',
      file_list,
      [:compressed]
    )
    # In order to provide upgrade/downgrade functionality, the archive needs to contain itself
    :ok = :erl_tar.create(
      '#{tarball}',
      [{'#{Path.join(["releases", version, "#{name}.tar.gz"])}', '#{tarball}.tmp'} | file_list],
      [:compressed]
    )
    # Clean up
    File.rm_rf! "#{tarball}.tmp"
    File.cp! tarball, release_tarball
    File.rm_rf! tarball

    # Continue..
    %{config | package: release_tarball}
  end

  defp parse_args(argv) do
    {args, _, _} = OptionParser.parse(argv)
    defaults = %Config{
      name:    Mix.Project.config |> Keyword.get(:app) |> Atom.to_string,
      version: Mix.Project.config |> Keyword.get(:version),
      env:     Mix.env
    }
    Enum.reduce args, defaults, fn arg, config ->
      case arg do
        {:verbosity, verbosity} ->
          verbosity = String.to_atom(verbosity)
          Logger.configure(verbosity)
          %{config | :verbosity => verbosity}
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

  defp extract_erts_version(%Config{relx_config: relx_config}) do
    include_erts = Keyword.get(relx_config, :include_erts, true)
    case include_erts do
      true  -> :erlang.system_info(:version) |> IO.iodata_to_binary
      false -> ""
      path  ->
        case File.ls("#{path}") do
          {:error, _}      -> ""
          {:ok, entries} ->
            erts = entries |> Enum.find(fn
              <<"erts-", _version::binary>> -> true
              _ -> false
            end)
            case erts do
              <<"erts-", version::binary>> -> version
              _ -> ""
            end
        end
    end
  end

end
