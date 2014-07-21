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
    schema_path  = Conform.Schema.schema_path(app)
    conf_path    = Path.join([File.cwd!, "config", "#{app}.conf"])

    # Ensure config directory exists
    Path.join(File.cwd!, "config") |> File.mkdir_p!

    debug "Conform: Updating schema..."
    # Get top-level schema...
    schema = Conform.Schema.read(app |> String.to_atom)
    # Get schemas from all dependencies
    dep_schemas = Conform.Schema.coalesce
    # Merge together
    merged = Conform.Schema.merge(dep_schemas, schema)
    # If the merged schema is non-empty, save the schema to config/{app}.schema.exs
    continue? = cond do
      merged == empty_schema ->
        warn "Conform: No schema found, proceeding without one."
        false
      true ->
        Conform.Schema.write_quoted(merged, schema_path)
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
        {:copy, schema_path  |> String.to_char_list, 'releases/#{version}/#{app}.schema.exs'},
        {:copy, conf_path    |> String.to_char_list, 'releases/#{version}/#{app}.conf'},
        {:copy, escript_path |> String.to_char_list, 'bin/conform'},
      ]]
      updated = Utils.merge(relx_config, overlays)
      # Persist relx.config
      Utils.write_terms(Utils.rel_file_dest_path("relx.config"), updated)

      info "Conform: Done!"
    end
  end

  def after_release(_), do: nil
  def after_cleanup(_), do: nil

end
