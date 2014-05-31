defmodule ReleaseManager.Plugin do
  @moduledoc """
  This module provide a simple way to add additional steps to
  the release task. You can define your own plugins using the
  sample definition below. Note that the module namespace must
  be nested under `ReleaseManager.Plugin.*`.

      defmodule ReleaseManager.Plugin.Hello do
        use ReleaseManager.Plugin

        def before_release(%Config{} = config) do
          info "This is executed just prior to compiling the release"
        end

        def after_release(%Config{} = config) do
          info "This is executed just after compiling the release"
        end

        def after_cleanup(_args) do
          info "This is executed just after running cleanup"
        end
      end

  A couple things are imported or aliased for you. Those things are:

  - The ReleaseManager.Config struct is aliased for you to just Config
  - `debug/1`, `info/1`, `warn/1`, `notice/1`, and `error/1` are imported for you.
    These should be used to do any output for the user.

  `before_release/1` and `after_release/1` are required callbacks, and will each be passed a
  `Config` struct, containing the configuration for the release task. You can choose
  to return the config struct modified or unmodified, or not at all. In the former case,
  any modifications you made will be passed on to the remaining plugins and the final
  release task. The required callback `after_cleanup/1` is passed the command line arguments. 
  The return value is not used. 

  All plugins are executed just prior, and just after compiling the release, as the name of
  the callbacks reflect. The `before_release/1` callback is called after some internal tasks,
  such as generating the sys.config and others.
  """
  use Behaviour

  @doc """
  A plugin needs to implement `before_release/1`, and `after_release/1` 
  both of which receive a %ReleaseManager.Config struct
  """
  defcallback before_release(ReleaseManager.Config.t) :: any
  defcallback after_release(ReleaseManager.Config.t) :: any

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour ReleaseManager.Plugin
      alias  ReleaseManager.Config
      import ReleaseManager.Utils, only: [debug: 1, info: 1, warn: 1, notice: 1, error: 1]
    end
  end

  @doc """
  Loads all plugins in all code paths.
  """
  @spec load_all() :: [] | [atom]
  def load_all, do: load_plugins(:code.get_path)

  @doc """
  Loads all plugins in the given `paths`.
  """
  @spec load_plugins([binary]) :: [] | [atom]
  def load_plugins(paths) do
    Enum.reduce(paths, [], fn(path, matches) ->
      {:ok, files} = :erl_prim_loader.list_dir(path |> String.to_char_list)
      Enum.reduce(files, matches, &match_plugins/2)
    end)
  end

  @re_pattern Regex.re_pattern(~r/Elixir\.ReleaseManager\.Plugin\..*\.beam$/)

  @spec match_plugins(char_list, [atom]) :: [atom]
  defp match_plugins(filename, modules) do
    if :re.run(filename, @re_pattern, [capture: :none]) == :match do
      mod = :filename.rootname(filename, '.beam') |> list_to_atom
      if Code.ensure_loaded?(mod), do: [mod | modules], else: modules
    else
      modules
    end
  end
end
