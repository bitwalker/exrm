defmodule ReleaseManager.Plugin.Conform do
  use   ReleaseManager.Plugin
  alias ReleaseManager.Config
  alias ReleaseManager.Utils

  def run(%Config{name: app, version: version}) do
    {:ok, relx_config} = Utils.rel_dest_path("relx.config")
      |> List.from_char_data!
      |> :file.consult
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
    updated = Enum.reduce relx_config, [], fn
      {:overlay, overlays}, config ->
        schema_overlay  = {:copy, schema_path |> List.from_char_data!, 'releases/#{version}/#{app}.schema.exs'}
        conf_overlay    = {:copy, conf_path |> List.from_char_data!, 'releases/#{version}/#{app}.conf'}
        escript_overlay = {:copy, escript_path |> List.from_char_data!, 'bin/conform'}
        [{:overlay, overlays ++ [schema_overlay, conf_overlay, escript_overlay]} | config]
      element, config ->
        [element | config]
    end
    # Persist relx.config
    format_str = String.duplicate("~p.\n\n", Enum.count(updated)) |> List.from_char_data!
    :file.write_file('#{Utils.rel_dest_path("relx.config")}', :io_lib.fwrite(format_str, updated |> Enum.reverse))

    info "Conform: Done!"
  end
end