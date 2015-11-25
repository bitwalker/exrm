defmodule ReleaseManager.Plugin do
  @moduledoc """
  This module provide a simple way to add additional steps to
  the release task.

  You can define your own plugins using the sample definition below. Note that
  the module namespace must be nested under `ReleaseManager.Plugin.*`.

      defmodule ReleaseManager.Plugin.Hello do
        use ReleaseManager.Plugin

        def before_release(%Config{} = config) do
          info "This is executed just prior to compiling the release"
        end

        def after_release(%Config{} = config) do
          info "This is executed just after compiling the release"
        end

        def after_package(%Config{} = config) do
          info "This is executed just after packaging the release"
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
  both of which receive a %ReleaseManager.Config struct, as well as `after_cleanup/1`, which
  receives the arguments given for the command as a list of strings.
  """
  @callback before_release(ReleaseManager.Config.t) :: any
  @callback after_release(ReleaseManager.Config.t) :: any
  @callback after_package(ReleaseManager.Config.t) :: any
  @callback after_cleanup([String.t]) :: any

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour ReleaseManager.Plugin
      alias  ReleaseManager.Config
      alias  ReleaseManager.Utils.Logger
      import Logger, only: [debug: 1, info: 1, warn: 1, notice: 1, error: 1]

      Module.register_attribute __MODULE__, :name, accumulate: false, persist: true
      Module.register_attribute __MODULE__, :moduledoc, accumulate: false, persist: true
      Module.register_attribute __MODULE__, :shortdoc, accumulate: false, persist: true
    end
  end

  @doc """
  Loads all plugins in all code paths.
  """
  @spec load_all() :: [] | [atom]
  def load_all, do: get_plugins(ReleaseManager.Plugin)

  # Loads all modules that extend a given module in the current code path.
  #
  # The convention is that it will fetch modules with the same root namespace,
  # and that are suffixed with the name of the module they are extending.
  @spec get_plugins(atom) :: [] | [atom]
  defp get_plugins(plugin_type) when is_atom(plugin_type) do
    available_modules(plugin_type) |> Enum.reduce([], &load_plugin/2)
  end

  defp load_plugin(module, modules) do
    if Code.ensure_loaded?(module), do: [module | modules], else: modules
  end

  defp available_modules(plugin_type) do
    # Ensure the current projects code path is loaded
    Mix.Task.run("loadpaths", [])
    # Fetch all .beam files
    Path.wildcard("**/*/ebin/**/*.{beam}")
    # Parse the BEAM for behaviour implementations
    |> Stream.map(fn path ->
      {:ok, {mod, chunks}} = :beam_lib.chunks('#{path}', [:attributes])
      {mod, get_in(chunks, [:attributes, :behaviour])}
    end)
    # Filter out behaviours we don't care about and duplicates
    |> Stream.filter(fn {_mod, behaviours} -> is_list(behaviours) && plugin_type in behaviours end)
    |> Enum.uniq
    |> Enum.map(fn {module, _} -> module end)
  end
end
