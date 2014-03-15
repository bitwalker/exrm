defmodule ExRM.Release.Utils do
  @moduledoc """
  This module provides helper functions for the `mix release` and
  `mix release.clean` tasks.
  """
  import Mix.Shell,    only: [cmd: 2]
  import Mix.Shell.IO, only: [cmd: 1]

  # Elixir constants
  @elixir_repo_url       "https://github.com/elixir-lang/elixir.git"
  @elixir_default_branch "stable"
  @elixir_build_path     "_elixir"
  @elixir_version_path   "#{@elixir_build_path}/VERSION"
  @mix_bin_path          "#{@elixir_build_path}/bin/mix"
  # Relx constants
  @relx_pkg_url          "https://github.com/erlware/relx/releases/download/v0.6.0/relx"
  @relx_executable       "relx"
  @relx_build_path       ".relx-build"
  @relx_config_path      "rel/relx.config"
  @relx_output_path      "rel"

  @doc """
  Call make in the current working directory.
  """
  def make(command \\ "", args \\ ""), do: cmd("make #{command} #{args}", &ignore/1)
  @doc """
  Call the _elixir mix binary with the given arguments
  """
  def mix(command, env \\ :dev), do: cmd("MIX_ENV=#{env} #{@mix_bin_path} #{command}", &ignore/1)
  @doc """
  Download a file from a url to the provided destination.
  """
  def wget(url, destination), do: cmd("wget -O #{destination} #{url}", &ignore/1)
  @doc """
  Change user permissions for a target file or directory
  """
  def chmod(target, flags), do: cmd("chmod #{flags} #{target}")
  @doc """
  Clone a git repository to the provided destination, or current directory
  """
  def clone(repo_url, destination), do: cmd("git clone #{repo_url} #{destination}", &ignore/1)
  def clone(repo_url, destination, branch) do
    case branch do
      :default -> clone repo_url, destination
      ""       -> clone repo_url, destination
      _        -> cmd "git clone --branch #{branch} #{repo_url} #{destination}", &ignore/1
    end
  end
  @doc """
  Execute `relx`
  """
  def relx(name, version \\ "", verbosity \\ :quiet) do
    # Setup paths
    config     = @relx_config_path
    output_dir = "#{@relx_output_path}/#{name}"
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
    cmd "./relx -V #{v} --config #{config} --relname #{name} --relvsn #{ver} --output-dir #{output_dir}"
    # tar.gz the release files for easy deployment
    package_release output_dir, name, ver
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

  #########
  # Elixir
  #########

  @doc """
  Clones the Elixir source, and checks out a specific branch or tag
  """
  def fetch_elixir(branch \\ :default) do
    if @elixir_build_path |> File.exists? do
      # pushd
      cwd = File.cwd!
      @elixir_build_path |> File.cd!
      # Make sure we have the desired branch checked out
      # Match against the current branch name as given by git
      case System.cmd("git rev-parse --abbrev-ref HEAD") do
        # Branch is the same, do nothing
        ^branch ->
          :ok
        # Branch is different, perform a checkout, blowing away any local changes
        _ ->
          case branch do
            :default -> System.cmd "git checkout --force #{@elixir_default_branch}"
            _        -> System.cmd "git checkout --force #{branch}"
          end
      end
      # popd
      cwd |> File.cd!
    else
      # This step should only happen the first time the release task is run, so let's remind
      # the user that this is going to take a minute to get through the next few steps.
      notice """
      This can take a few minutes depending on your internet connection 
      and how powerful of a machine you have. Since this is a fresh release
      from scratch, we need to clone the Elixir repo and perform a build.
      So I'd recommend grabbing a coffee :)
      """
      debug "Fetching Elixir..."
      # Clone the Elixir repo
      case branch do
        :default -> clone @elixir_repo_url, @elixir_build_path, @elixir_default_branch
        _        -> clone @elixir_repo_url, @elixir_build_path, branch
      end
    end
  end

  @doc """
  Will build Elixir, and remove any test directories to prevent warnings
  during release due to invalid *.app files in the tests.
  """
  def build_elixir do
    debug "Building Elixir..."
    # pushd, make, popd
    cwd = File.cwd!
    @elixir_build_path |> File.cd! 
    make
    cwd |> File.cd!
    
    # Delete test subdirectories to prevent false "App metadata file found but malformed" warnings
    elixir_lib_path = Path.join([File.cwd!, @elixir_build_path, "lib"])
    # This will list out all of the subdirs of Elixir's `lib` folder,
    # filter the list for only directories that are named `test`, then
    # delete them. We can be assured this is contained to the Elixir
    # source tree, because `elixir_lib_path` is an absolute path.
    elixir_lib_path
    |> File.ls!
    |> Enum.map(fn dir -> Path.join([elixir_lib_path, dir, "test"]) end)
    |> Enum.filter(&File.dir?/1)
    |> Enum.filter(&File.exists?/1)
    |> Enum.map(&File.rm_rf!/1)
  end

  @doc """
  Remove the Elixir source/build directory
  """
  def clean_elixir do
    if @elixir_build_path |> File.exists? do
      @elixir_build_path |> File.rm_rf!
    end
  end

  #########
  # Relx
  #########

  @doc """
  Downloads the relx executable
  """
  def fetch_relx do
    unless @relx_executable |> File.exists? do
      debug "Downloading relx..."
      wget @relx_pkg_url, @relx_executable
      @relx_executable |> chmod("+x")
    end
  end

  @doc """
  Remove the relx executable
  """
  def clean_relx do
    if @relx_executable |> File.exists? do
      @relx_executable |> File.rm_rf!
    end
  end

  defp package_release(release_path, name, version) do
    # pushd
    cwd = File.cwd!
    release_path |> File.cd!
    # tar up the release files
    debug "Creating release package..."
    cmd "tar -czf #{name}-#{version}.tar.gz lib releases erts* bin"
    # popd
    cwd |> File.cd!
  end

  # Ignore a message when used as the callback for Mix.Shell.cmd
  defp ignore(_), do: nil 
  # Get the release Elixir version
  #defp elixir_version, do: System.cmd "cat #{@elixir_version_path}"

end