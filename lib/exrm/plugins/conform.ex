defmodule ReleaseManager.Plugin.Conform do
  @name "conform"
  @shortdoc "Generates a .conf for your release"
  @moduledoc """
  Generates a .conf for your release

  This plugin ensures that your application has a .schema.exs
  and .conf file for setting up configuration via the `conform`
  library. This .conf file then offers a simplified interface
  for sysadmins and other deployment staff for easily configuring
  your release in production.
  """
  
  use   ReleaseManager.Plugin
  alias ReleaseManager.Config
  alias ReleaseManager.Utils

  def before_release(%Config{name: app, version: version}) do
    empty_schema = Conform.Schema.empty
    relx_config  = Utils.rel_file_dest_path("relx.config") |> Utils.read_terms
    conf_path    = Path.join([File.cwd!, "config", "#{app}.conf"])

    # Ensure config directory exists
    Path.join(File.cwd!, "config") |> File.mkdir_p!

    debug "Conform: Updating schema..."
    # Get top-level schema...
    schema = load_schema(app)
    # Get schemas from all dependencies
    proj_config = [build_path: Mix.Project.build_path, umbrella?: Mix.Project.umbrella?]
    dep_schemas = for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.loaded([]) do
      Mix.Project.in_project(app, opts[:path], proj_config, &(load_schema(app, &1)))
    end
    # Merge schemas
    merged = dep_schemas |> Enum.reduce(schema, &merge_schema/2)
    # If the merged schema is non-empty, save the schema to config/{app}.schema.exs
    continue? = case merged do
      ^empty_schema ->
        warn "Conform: No schema found, proceeding without one."
        false
      _ ->
        Conform.Schema.write(merged, schema_path(app))
        info "Conform: #{app}.schema.exs updated succesfully!"
        true
    end

    if continue? do
      debug "Conform: Checking for #{app}.conf..."
      # If .conf is not found, generate default one
      unless File.exists?(conf_path) do
        warn "Conform: No .conf found, generating one at config/#{app}.conf"
        Mix.Task.run("conform.configure")
      end
      # Generate escript for release
      debug "Conform: Generating escript.."
      escript_path = Mix.Task.run("conform.release")
      # Add .conf, .schema.exs, and escript to relx.config as overlays
      debug "Conform: Adding overlays to relx.config"
      overlays = [overlay: [
        {:copy, schema_path(app) |> String.to_char_list, 'releases/#{version}/#{app}.schema.exs'},
        {:copy, conf_path        |> String.to_char_list, 'releases/#{version}/#{app}.conf'},
        {:copy, escript_path     |> String.to_char_list, 'bin/conform'},
      ]]
      updated = Utils.merge(relx_config, overlays)
      # Persist relx.config
      Utils.write_terms(Utils.rel_file_dest_path("relx.config"), updated)

      info "Conform: Done!"
    end
  end

  def after_release(_), do: nil
  def after_cleanup(_), do: nil

  defp load_schema(app), do: load_schema(app, nil)
  defp load_schema(app, _) do
    path = app |> schema_path
    case File.exists?(path) do
      true  -> path |> Conform.Schema.load
      false -> Conform.Schema.empty
    end
  end

  defp schema_path(app), do: Path.join([File.cwd!, "config", "#{app}.schema.exs"])

  defp merge_schema(new, old) do
    mappings     = merge_mappings(Keyword.get(new, :mappings, []), Keyword.get(old, :mappings, []))
    translations = merge_translations(Keyword.get(new, :translations, []), Keyword.get(old, :translations, []))
    [mappings: mappings, translations: translations]
  end
  defp merge_mappings(new, old) do
    # Iterate over each mapping in new, and add it if it doesn't
    # exist in old, otherwise, do nothing
    new |> Enum.reduce(old, fn {key, mapping}, acc ->
      case acc |> Keyword.get(key) do
        nil -> acc ++ [{key, mapping}]
        _   -> acc
      end
    end)
  end
  defp merge_translations(new, old) do
    # Iterate over each translation in new, and add it if it doesn't
    # exist in old, otherwise, do nothing
    new |> Enum.reduce(old, fn {key, translation}, acc ->
      case acc |> Keyword.get(key) do
        nil -> acc ++ [{key, translation}]
        _   -> acc
      end
    end)
  end
end
