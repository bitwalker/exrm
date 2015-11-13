defmodule Mix.Tasks.Release.Plugins do
  @moduledoc """
  View information about active release plugins

  ## Examples

      # View all active plugins
      mix release.plugins

      # View detailed info about a plugin, if available
      mix release.plugins <plugin_name>

  """
  @shortdoc "View information about active release plugins"

  use    Mix.Task
  alias  ReleaseManager.Utils.Logger
  import ReleaseManager.Utils

  def run(args) do
    {:ok, _} = Logger.start_link
    args |> parse_args |> do_run
  end

  defp do_run([action: :list]) do
    case get_plugins do
      []      -> IO.puts "No plugins found!"
      plugins ->
        for plugin <- plugins do
          name     = get_name(plugin)
          shortdoc = get_shortdoc(plugin)
          IO.puts String.ljust(name, 30) <> " # " <> shortdoc
        end
    end
  end
  defp do_run([action: :details, plugin: plugin]) do
    plugin |> get_plugin |> display_plugin_long
  end

  defp get_plugins, do: ReleaseManager.Plugin.load_all

  defp get_plugin(plugin) do
    plugin_name = plugin |> String.downcase
    result = ReleaseManager.Plugin.load_all |> Enum.find(fn module ->
      module_name = module |> Atom.to_string |> String.downcase
      given_name  = get_name(module) |> String.downcase
      cond do
        module_name |> String.contains?(plugin_name) -> true
        given_name |> String.contains?(plugin_name)  -> true
        true -> false
      end
    end)
    case result do
      nil ->
        Logger.notice "No plugin by that name could be found!"
        abort!
      _ ->
        result
    end
  end

  defp display_plugin_long(plugin) do
    name      = get_name(plugin)
    moduledoc = get_moduledoc(plugin)
    if IO.ANSI.enabled? do
      opts = [width: 80]
      IO.ANSI.Docs.print_heading("#{name}", opts)
      IO.ANSI.Docs.print(moduledoc, opts)
    else
      IO.puts "# #{name}\n"
      IO.puts moduledoc
    end
  end

  defp get_name(plugin) do
    default = plugin |> Atom.to_string |> String.replace(~r/.*\./, "") |> String.downcase
    get_plugin_info(plugin, :name, default)
  end
  defp get_shortdoc(plugin),  do: get_plugin_info(plugin, :shortdoc, "No description available.")
  defp get_moduledoc(plugin), do: get_plugin_info(plugin, :moduledoc, "No additional details available.")

  defp get_plugin_info(plugin, type, default) when is_atom(plugin) and is_atom(type) do
    case plugin.__info__(:attributes) |> List.keyfind(type, 0) do
      {^type, [value]} -> value
      nil            -> default
    end
  end

  defp parse_args(args) do
    case OptionParser.parse(args) do
      {_, [], _} -> [action: :list]
      {_, [plugin], _} -> [action: :details, plugin: plugin]
      {_, _, _} ->
        Logger.error "Invalid arguments for `mix release.plugins`!"
        abort!
    end
  end

end
