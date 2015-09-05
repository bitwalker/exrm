defmodule ReleaseManager.Plugin.Appups do
  @name "appup"
  @shortdoc "Generates a .appup for each dependency in your project"
  @moduledoc """
  Generates a .appup for each dependency in your project
  """

  use   ReleaseManager.Plugin
  alias ReleaseManager.Config
  alias ReleaseManager.Utils
  alias ReleaseManager.Appups

  def before_release(%Config{upgrade?: true, env: env} = config) do
    debug "Generating appups for dependencies in the #{env} environment..."
    deps = Mix.Dep.loaded(env: env)

    do_appup(config, deps)
  end
  def before_release(_), do: nil

  def do_appup(_config, []), do: info "All dependencies have appups ready for release!"
  def do_appup(config, [%Mix.Dep{app: :exrm}|deps]), do: do_appup(config, deps)
  def do_appup(%Config{name: project} = config, [%Mix.Dep{app: app, opts: opts}|deps]) do
    debug "Checking #{app}.."

    last_release = Utils.get_last_release(project)
    last_release_definition = Utils.rel_dest_path [project, "releases", last_release, "#{project}.rel"]
    [{:release, _app, _erts, apps}] = Utils.read_terms(last_release_definition)
    case List.keyfind(apps, app, 0) do
      nil ->
        debug "No appup required for #{app}."
      app_info ->
        last_app_version = "#{elem(app_info, 1)}"
        v1_path          = Utils.rel_dest_path [project, "lib", "#{app}-#{last_app_version}"]
        v2_path          = Keyword.get(opts, :build)
        v2_ebin_path     = Path.join(v2_path, "ebin")

        [{:application, _app, info}] = Path.join(v2_ebin_path, "#{app}.app") |> Utils.read_terms
        current_app_version = "#{Keyword.get(info, :vsn)}"
        appup_path          = Path.join(v2_ebin_path, "#{app}.appup")
        appup_exists?       = File.exists?(appup_path)

        cond do
          current_app_version == last_app_version ->
            debug "No appup required for #{app}."
          appup_exists? ->
            debug "#{app} already has an appup, skipping generation."
          true ->
            debug "Generating appup for #{app}"
            case Appups.make(app, last_app_version, current_app_version, v1_path, v2_path) do
              {:error, reason} ->
                error "Failed to generate appup for #{app}: #{reason}"
              {:ok, _appup} ->
                info "Generated .appup for #{app} #{last_app_version} -> #{current_app_version}"
            end
        end
    end

    do_appup(config, deps)
  end

  def after_release(_), do: nil
  def after_package(_), do: nil
  def after_cleanup(_), do: nil

end
