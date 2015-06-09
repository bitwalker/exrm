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
    empty_schema   = Conform.Schema.empty
    relx_conf_path = Utils.rel_file_dest_path("relx.config")
    schema_dest    = Utils.rel_file_dest_path("#{app}.schema.exs")
    conf_src       = Path.join([File.cwd!, "config", "#{app}.conf"])

    debug "Conform: Loading schema..."
    # Get top-level schema...
    schema = app |> String.to_atom |> Conform.Schema.read!
    # Get schemas from all dependencies
    dep_schemas = Conform.Schema.coalesce
    # Merge together
    merged = Conform.Schema.merge(dep_schemas, schema)
    # If the merged schema is non-empty, save the schema to config/{app}.schema.exs
    continue? = cond do
      merged == empty_schema ->
        warn "Conform: No schema found, conform will not be packaged in this release!"
        false
      true ->
        Conform.Schema.write_quoted(merged, schema_dest)
        info "Conform: Schema succesfully loaded!"
        true
    end

    if continue? do
      # Define overlays for relx.config
      overlays = [{:copy, '#{schema_dest}', 'releases/#{version}/#{app}.schema.exs'}]
      overlays = case File.exists?(conf_src) do
        true ->
          [{:copy, '#{conf_src}', 'releases/#{version}/#{app}.conf'}|overlays]
        false ->
          overlays
      end

      # Generate escript for release
      debug "Conform: Generating escript.."
      escript_path = Mix.Task.run("conform.release")
      overlays = [{:copy, escript_path |> String.to_char_list, 'bin/conform'}|overlays]

      # Add .conf, .schema.exs, and escript to relx.config as overlays
      debug "Conform: Adding overlays to relx.config..."
      relx_config = relx_conf_path |> Utils.read_terms 
      updated = Utils.merge(relx_config, [overlay: overlays])

      # Persist relx.config
      Utils.write_terms(relx_conf_path, updated)

      info "Conform: Done!"
    end
  end

  def after_release(_), do: nil
  def after_package(_), do: nil
  def after_cleanup(_), do: nil

end
