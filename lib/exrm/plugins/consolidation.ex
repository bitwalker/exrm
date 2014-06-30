defmodule ReleaseManager.Plugin.Consolidation do
  use    ReleaseManager.Plugin
  alias  ReleaseManager.Config
  alias  ReleaseManager.Utils
  import ReleaseManager.Utils

  def before_release(%Config{verbosity: verbosity}) do
    debug "Performing protocol consolidation..."
    with_env :prod do
      cond do
        verbosity == :verbose ->
          mix "compile.protocols", :prod, :verbose
        true ->
          mix "compile.protocols", :prod
      end
    end

    # Load relx.config
    {:ok, relx_config} = Utils.rel_dest_path("relx.config")
      |> String.to_char_list
      |> :file.consult

    # Add overlay to relx.config which copies consolidated dir to release
    updated = Enum.reduce relx_config, [], fn
      {:overlay, overlays}, config ->
        consolidated_path    = Path.join([File.cwd!, "_build", "prod", "consolidated"])
        consolidated_overlay = {:copy, consolidated_path |> String.to_char_list, 'lib/consolidated'}
        [{:overlay, overlays ++ [consolidated_overlay]} | config]
      element, config ->
        [element | config]
    end
    # Persist relx.config
    format_str = String.duplicate("~p.\n\n", Enum.count(updated)) |> String.to_char_list
    :file.write_file('#{Utils.rel_dest_path("relx.config")}', :io_lib.fwrite(format_str, updated |> Enum.reverse))
  end

  def after_release(_), do: nil
  def after_cleanup(_), do: nil
end