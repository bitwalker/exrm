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
    relx_config = Utils.rel_file_dest_path("relx.config") |> Utils.read_terms
    schema_path = Path.join([File.cwd!, "config", "#{app}.schema.exs"])
    conf_path   = Path.join([File.cwd!, "config", "#{app}.conf"])

    # Ensure config directory exists
    Path.join(File.cwd!, "config") |> File.mkdir_p!

    debug "Conform: Checking for #{app}.schema.exs..."
    # If schema is not found, generate one
    unless File.exists?(schema_path) do
      warn "Conform: No schema found, generating one at config/#{app}.schema.exs"
      Mix.Task.run("conform.new")
    end
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

  def after_release(_), do: nil
  def after_cleanup(_), do: nil
end
