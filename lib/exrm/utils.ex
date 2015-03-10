defmodule ReleaseManager.Utils do
  @moduledoc """
  This module provides helper functions for the `mix release` and
  `mix release.clean` tasks.
  """
  import Mix.Shell,    only: [cmd: 2]

  # Relx constants
  @relx_output_path      "rel"

  @doc """
  Perform some actions within the context of a specific mix environment
  """
  def with_env(env, fun) do
    old_env = Mix.env
    try do
      # Change env
      Mix.env(env)
      fun.()
    after
      # Change back
      Mix.env(old_env)
    end
  end

  @doc """
  Load the current project's configuration
  """
  def load_config(env) do
    with_env env, fn ->
      if File.regular?("config/config.exs") do
        Mix.Config.read! "config/config.exs"
      else
        []
      end
    end
  end

  @doc """
  Call the _elixir mix binary with the given arguments
  """
  def mix(command, :quiet),        do: mix(command, :dev, :quiet)
  def mix(command, :verbose),      do: mix(command, :dev, :verbose)
  def mix(command, env),           do: mix(command, env, :quiet)
  def mix(command, env, :quiet),   do: do_cmd("MIX_ENV=#{env} mix #{command}", &ignore/1)
  def mix(command, env, :verbose), do: do_cmd("MIX_ENV=#{env} mix #{command}", &IO.write/1)
  @doc """
  Change user permissions for a target file or directory
  """
  def chmod(target, flags), do: do_cmd("chmod #{flags} #{target}", &ignore/1)
  @doc """
  Execute `relx`
  """
  def relx(name, version, verbosity, upgrade?, dev) do
    # Setup paths
    config     = rel_file_dest_path "relx.config"
    output_dir = @relx_output_path |> Path.expand
    # Determine whether to pass --dev-mode or not
    dev_mode?  = case dev do
      true  -> "--dev-mode"
      false -> ""
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
      false -> "#{relx_path} release tar -V #{v} --root #{File.cwd!} --config #{config} --relname #{name} --relvsn #{version} --output-dir #{output_dir} #{dev_mode?}"
      true  ->
        last_release = get_last_release(name)
        "#{relx_path} release relup tar -V #{v} --root #{File.cwd!} --config #{config} --relname #{name} --relvsn #{version} --output-dir #{output_dir} --upfrom \"#{last_release}\" #{dev_mode?}"
    end
    case do_cmd command do
      :ok         -> :ok
      {:error, _} ->
        {:error, "Failed to build release. Please fix any errors and try again."}
    end
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

  @doc "Exits with exit status 1"
  def abort!, do: exit({:shutdown, 1})

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
        |> Enum.reject(fn entry -> entry in ["RELEASES", "start_erl.data"] end)
        |> Enum.map(fn version -> {project, version} end)
    end
  end

  @doc """
  Get the most recent release prior to the current one
  """
  def get_last_release(project) do
    hd(project |> get_releases |> Enum.map(fn {_, v} -> v end) |> sort_versions)
  end

  @doc """
  Sort a list of versions, latest one first. Tries to use semver version 
  compare, but can fall back to regular string compare.
  """
  def sort_versions(versions) do
    versions |> Enum.sort(
      fn v1, v2 ->
        case { parse_semver(v1), parse_semver(v2) } do
          {{:semantic, v1}, {:semantic, v2}} ->
            case Version.compare(v1, v2) do
              :gt -> true
              _   -> false
            end;
          {{_, v1}, {_, v2}} ->
            v1 >  v2
        end
      end)
  end

  defp parse_version(ver) do
    case Version.parse(ver) do
      {:ok, semver} -> {:semantic, semver}
      :error        -> {:nonsemantic, ver}
    end
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

  @doc """
  Writes a collection of Elixir/Erlang terms to the provided path
  """
  def write_terms(path, terms) when is_list(terms) do
    format_str = String.duplicate("~p.\n\n", Enum.count(terms)) |> String.to_char_list
    :file.write_file('#{path}', :io_lib.fwrite(format_str, terms |> Enum.reverse))
  end

  @doc """
  Reads a file as Erlang terms
  """
  def read_terms(path) do
    result = case '#{path}' |> :file.consult do
      {:ok, terms} ->
        terms
      {:error, {line, type, msg}} ->
        error "Unable to parse #{path}: Line #{line}, #{type}, - #{msg}"
        abort!
      {:error, reason} ->
        error "Unable to access #{path}: #{reason}"
        abort!
    end
    result
  end

  @doc """
  Convert a string to Erlang terms
  """
  def string_to_terms(str) do
    str
    |> String.split("}.")
    |> Stream.map(&(String.strip(&1, ?\n)))
    |> Stream.map(&String.strip/1)
    |> Stream.map(&('#{&1}}.'))
    |> Stream.map(&(:erl_scan.string(&1)))
    |> Stream.map(fn {:ok, tokens, _} -> :erl_parse.parse_term(tokens) end)
    |> Stream.filter(fn {:ok, _} -> true; {:error, _} -> false end)
    |> Enum.reduce([], fn {:ok, term}, acc -> [term|acc] end)
    |> Enum.reverse
  end

  @doc """
  Merges two sets of Elixir/Erlang terms, where the terms come
  in the form of lists of tuples. For example, such as is found
  in the relx.config file
  """
  def merge(old, new) when is_list(old) and is_list(new) do
    merge(old, new, [])
  end

  defp merge([h|t], new, acc) when is_tuple(h) do
    case :lists.keytake(elem(h, 0), 1, new) do
      {:value, new_value, rest} ->
        # Value is present in new, so merge the value
        merged = merge_term(h, new_value)
        merge(t, rest, [merged|acc])
      false ->
        # Value doesn't exist in new, so add it
        merge(t, new, [h|acc])
    end
  end
  defp merge([], new, acc) do
    Enum.reverse(acc, new)
  end

  defp merge_term(old, new) when is_tuple(old) and is_tuple(new) do
    old
    |> Tuple.to_list
    |> Enum.with_index
    |> Enum.reduce([], fn
        {[], idx}, acc ->
          [elem(new, idx)|acc]
        {val, idx}, acc when is_list(val) ->
          case :io_lib.char_list(val) do
            true ->
              [elem(new, idx)|acc]
            false ->
              merged = val |> Enum.concat(elem(new, idx)) |> Enum.uniq
              [merged|acc]
          end
        {val, idx}, acc when is_tuple(val) ->
          [merge_term(val, elem(new, idx))|acc]
        {_val, idx}, acc ->
          [elem(new, idx)|acc]
       end)
    |> Enum.reverse
    |> List.to_tuple
  end

  @doc "Get the priv path of the exrm dependency"
  def priv_path, do: "#{:code.priv_dir('exrm')}"
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
            sym |> IO.iodata_to_binary
          :relative ->
            symlink = sym |> IO.iodata_to_binary
            path |> Path.dirname |> Path.join(symlink) |> Path.expand
        end
    end |> String.replace("/bin/elixir", "")
  end

end
