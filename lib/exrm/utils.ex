defmodule ReleaseManager.Utils do
  @moduledoc """
  This module provides helper functions for the `mix release` and
  `mix release.clean` tasks.
  """
  import Mix.Shell,    only: [cmd: 2]

  # Relx constants
  @relx_config_path      "rel/relx.config"
  @relx_output_path      "rel"

  @doc """
  Perform some actions within the context of a specific mix environment
  """
  defmacro with_env(env, body) do
    quote do
      old_env = Mix.env
      # Change env
      Mix.env(unquote(env))
      unquote(body)
      # Change back
      Mix.env(old_env)
    end
  end


  @doc """
  Rip 0.13.3's `reraise` macro for 0.13.2, remove once 0.13.3 is released
  """
  defmacro reraise(msg, stacktrace) do
     # Try to figure out the type at compilation time
    # to avoid dead code and make dialyzer happy.

    case Macro.expand(msg, __CALLER__) do
      msg when is_binary(msg) ->
        quote do
          :erlang.raise :error, RuntimeError.exception(unquote(msg)), unquote(stacktrace)
        end
      {:<<>>, _, _} = msg ->
        quote do
          :erlang.raise :error, RuntimeError.exception(unquote(msg)), unquote(stacktrace)
        end
      alias when is_atom(alias) ->
        quote do
          :erlang.raise :error, unquote(alias).exception([]), unquote(stacktrace)
        end
      msg ->
        quote do
          stacktrace = unquote(stacktrace)
          case unquote(msg) do
            msg when is_binary(msg) ->
              :erlang.raise :error, RuntimeError.exception(msg), stacktrace
            atom when is_atom(atom) ->
              :erlang.raise :error, atom.exception([]), stacktrace
            %{__struct__: struct, __exception__: true} = other when is_atom(struct) ->
              :erlang.raise :error, other, stacktrace
          end
        end
    end
  end

  @doc """
  Call make in the current working directory.
  """
  def make(:quiet),                  do: make("", "", :quiet)
  def make(:verbose),                do: make("", "", :verbose)
  def make(command, :quiet),         do: make(command, "", :quiet)
  def make(command, :verbose),       do: make(command, "", :verbose)
  def make(command, args),           do: make(command, args, :quiet)
  def make(command, args, :quiet),   do: do_cmd("make #{command} #{args}", &ignore/1)
  def make(command, args, :verbose), do: do_cmd("make #{command} #{args}", &IO.write/1)
  @doc """
  Call the _elixir mix binary with the given arguments
  """
  def mix(command, :quiet),        do: mix(command, :dev, :quiet)
  def mix(command, :verbose),      do: mix(command, :dev, :verbose)
  def mix(command, env),           do: mix(command, env, :quiet)
  def mix(command, env, :quiet),   do: do_cmd("MIX_ENV=#{env} mix #{command}", &ignore/1)
  def mix(command, env, :verbose), do: do_cmd("MIX_ENV=#{env} mix #{command}", &IO.write/1)
  @doc """
  Download a file from a url to the provided destination.
  """
  def wget(url, destination), do: do_cmd("wget -O #{destination} #{url}", &ignore/1)
  @doc """
  Change user permissions for a target file or directory
  """
  def chmod(target, flags), do: do_cmd("chmod #{flags} #{target}", &ignore/1)
  @doc """
  Clone a git repository to the provided destination, or current directory
  """
  def clone(repo_url, destination), do: do_cmd("git clone #{repo_url} #{destination}", &ignore/1)
  def clone(repo_url, destination, branch) do
    case branch do
      :default -> clone repo_url, destination
      ""       -> clone repo_url, destination
      _        -> do_cmd "git clone --branch #{branch} #{repo_url} #{destination}", &ignore/1
    end
  end
  @doc """
  Execute `relx`
  """
  def relx(name, version, verbosity, upgrade?, dev) do
    # Setup paths
    config     = @relx_config_path
    output_dir = @relx_output_path
    # Determine whether to pass --dev-mode or not
    dev_mode?  = case dev do 
      true  -> "--dev-mode"
      false -> ""
    end
    # Get the release version
    ver = case version do
      "" -> git_describe
      _  -> version
    end
    # Convert friendly verbosity names to relx values
    v = case verbosity do
      :silent  -> 0
      :quiet   -> 1
      :normal  -> 2
      :verbose -> 3
      _        -> 2 # Normal if we get an odd value
    end
    # Let relx do the heavy lifting
    relx_path = Path.join([priv_path, "bin", "relx"])
    command = case upgrade? do
      false -> "#{relx_path} release tar -V #{v} --root #{File.cwd!} --config #{config} --relname #{name} --relvsn #{ver} --output-dir #{output_dir} #{dev_mode?}"
      true  ->
        last_release = get_last_release(name)
        "#{relx_path} release relup tar -V #{v} --root #{File.cwd!} --config #{config} --relname #{name} --relvsn #{ver} --output-dir #{output_dir} --upfrom \"#{last_release}\" #{dev_mode?}"
    end
    case do_cmd command do
      :ok         -> :ok
      {:error, _} ->
        {:error, "Failed to build release. Please fix any errors and try again."}
    end
  end
  @doc """
  Get the current project revision's short hash from git
  """
  def git_describe do
    System.cmd "git describe --always --tags | sed -e s/^v//"
  end

  @doc "Print an informational message without color"
  def debug(message), do: IO.puts "==> #{message}"
  @doc "Print an informational message in green"
  def info(message),  do: IO.puts "==> #{IO.ANSI.green}#{message}#{IO.ANSI.reset}"
  @doc "Print a warning message in yellow"
  def warn(message),  do: IO.puts "==> #{IO.ANSI.yellow}#{message}#{IO.ANSI.reset}"
  @doc "Print a notice in yellow"
  def notice(message), do: IO.puts "#{IO.ANSI.yellow}#{message}#{IO.ANSI.reset}"
  @doc "Print an error message in red"
  def error(message), do: IO.puts "==> #{IO.ANSI.red}#{message}#{IO.ANSI.reset}"

  @doc """
  Get a list of tuples representing the previous releases:

    ## Examples

    get_releases #=> [{"test", "0.0.1"}, {"test", "0.0.2"}]
  """
  def get_releases(project) do
    release_path = Path.join([File.cwd!, "rel", project, "releases"])
    case release_path |> File.exists? do
      false -> []
      true  ->
        release_path
        |> File.ls!
        |> Enum.reject(fn entry -> entry == "RELEASES" end)
        |> Enum.map(fn version -> {project, version} end)
    end
  end

  @doc """
  Get the most recent release prior to the current one
  """
  def get_last_release(project) do
    [{_,version} | _] = project |> get_releases |> Enum.sort(fn {_, v1}, {_, v2} -> v1 > v2 end)
    version
  end

  @doc """
  Get the local path of the current elixir executable
  """
  def get_elixir_path() do
    System.find_executable("elixir") |> get_real_path
  end

  @doc """
  Writes an Elixir/Erlang term to the provided path
  """
  def write_term(path, term) do
    :file.write_file('#{path}', :io_lib.fwrite('~p.\n', [term]))
  end

  @doc "Get the priv path of the exrm dependency"
  def priv_path, do: Path.join([__DIR__, "..", "..", "priv"]) |> Path.expand
  @doc "Get the priv/rel path of the exrm dependency"
  def rel_source_path,       do: Path.join(priv_path, "rel")
  @doc "Get the path to a file located in priv/rel of the exrm dependency"
  def rel_source_path(file), do: Path.join(rel_source_path, file)
  @doc "Get the priv/rel/files path of the exrm dependency"
  def rel_file_source_path,       do: Path.join([priv_path, "rel", "files"])
  @doc "Get the path to a file located in priv/rel/files of the exrm dependency"
  def rel_file_source_path(file), do: Path.join(rel_file_source_path, file)
  @doc """
  Get the path to a file located in the rel directory of the current project.
  You can pass either a file name, or a list of directories to a file, like:

    iex> ReleaseManager.Utils.rel_dest_path "relx.config"
    "path/to/project/rel/relx.config"
    iex> ReleaseManager.Utils.rel_dest_path ["<project>", "lib", "<project>.appup"]
    "path/to/project/rel/<project>/lib/<project>.appup"

  """
  def rel_dest_path(files) when is_list(files), do: Path.join([rel_dest_path] ++ files)
  def rel_dest_path(file),                      do: Path.join(rel_dest_path, file)
  @doc "Get the rel path of the current project."
  def rel_dest_path,                            do: Path.join(File.cwd!, "rel")
  @doc """
  Get the path to a file located in the rel/files directory of the current project.
  You can pass either a file name, or a list of directories to a file, like:

    iex> ReleaseManager.Utils.rel_file_dest_path "sys.config"
    "path/to/project/rel/files/sys.config"
    iex> ReleaseManager.Utils.rel_dest_path ["some", "path", "file.txt"]
    "path/to/project/rel/files/some/path/file.txt"

  """
  def rel_file_dest_path(files) when is_list(files), do: Path.join([rel_file_dest_path] ++ files)
  def rel_file_dest_path(file),                      do: Path.join(rel_file_dest_path, file)
  @doc "Get the rel/files path of the current project."
  def rel_file_dest_path,                            do: Path.join([File.cwd!, "rel", "files"])

  # Ignore a message when used as the callback for Mix.Shell.cmd
  defp ignore(_), do: nil

  defp do_cmd(command), do: do_cmd(command, &IO.write/1)
  defp do_cmd(command, callback) do
    case cmd(command, callback) do
      0 -> :ok
      _ -> {:error, "Release step failed. Please fix any errors and try again."}
    end
  end

  defp get_real_path(path) do
    case path |> String.to_char_list |> :file.read_link_info do
      {:ok, {:file_info, _, :regular, _, _, _, _, _, _, _, _, _, _, _}} ->
        path
      {:ok, {:file_info, _, :symlink, _, _, _, _, _, _, _, _, _, _, _}} ->
        {:ok, sym} = path |> String.to_char_list |> :file.read_link
        case sym |> :filename.pathtype do
          :absolute ->
            sym |> iodata_to_binary
          :relative ->
            symlink = sym |> iodata_to_binary
            path |> Path.dirname |> Path.join(symlink) |> Path.expand
        end
    end |> String.replace("/bin/elixir", "")
  end

end
