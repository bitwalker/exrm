defmodule ReleaseManager.Deps do
  @moduledoc """
  This module provides functions for retrieving dependency information.
  """

  @doc """
  Discovers missing applications which could prevent a release from running properly.
  Returns a tree to be formatted for output. The tree is a nested kwlist.
  """
  def get_missing_applications(options \\ []), do: get_missing_applications(Mix.Dep.loaded([]), options)
  def get_missing_applications(deps, options) when is_list(deps) and is_list(options) do
    ignore        = Keyword.get(options, :ignore, [])
    implicits     = flatten_tree(get_implicit_applications(ignore))
    project_apps  = get_project_apps(Mix.Project.get!)
    included_apps = [{Mix.Project.config[:app], project_apps} | get_included_applications(deps)]

    deps
    |> get_dependency_tree
    |> map_dependency_tree(fn app_name -> Enum.find(deps, fn %Mix.Dep{app: a} -> app_name == a end) end)
    |> filter_dependency_tree(fn %Mix.Dep{app: app, opts: opts} ->
      case is_dep_required?(opts) && not app in implicits do
        false -> false
        true ->
          # If this app is included by another application, ignore it
          not Enum.any?(included_apps, fn {_, children} ->
            app in children
          end)
      end
    end)
    |> map_dependency_tree(fn %Mix.Dep{app: app} -> app end)
  end

  @doc """
  Produces a list of lines to be printed, which display each missing application,
  the depedency graph representing where it comes from, and a short message describing
  where it should be added:

  ## Example

      exrm -> conform -> neotoma          => neotoma is missing from conform
      exrm -> relx -> providers -> getopt => getopt is missing from providers
      exrm -> relx -> getopt              => getopt is missing from relx
      exrm -> relx -> erlware_commons     => erlware_commons is missing from relx
      exrm -> relx -> bbmustache          => bbmustache is missing from relx
  """
  def print_missing_applications(options \\ []) do
    deps = Mix.Dep.loaded([])
    ignore = Keyword.get(options, :ignore, [])
    case get_missing_app_paths(get_missing_applications(deps, ignore: ignore), []) do
      [] -> ""
      missing_apps ->
        parents = missing_apps
                  |> Enum.map(fn
                    path when is_list(path) ->
                      List.first(Enum.drop(path, Enum.count(path) - 2))
                    path when is_atom(path) ->
                      path
                  end)
                  |> Enum.uniq
                  |> Enum.map(fn app -> {app, Enum.find(deps, fn %Mix.Dep{app: a} -> a == app end)} end)
        missing_apps
        |> Enum.uniq
        |> Enum.map(fn
          path when is_list(path) ->
            parent = List.first(Enum.drop(path, Enum.count(path) - 2))
            dep = Keyword.get(parents, parent)
            {path, dep}
          path when is_atom(path) ->
            {[path], nil}
        end)
        |> format_requirements
    end
  end

  # Formats the requirements built in `print_missing_applications/0`
  defp format_requirements(apps) do
    apps = Enum.map(apps, fn {app_path, from_dep} ->
      path_str     = Enum.join(app_path, " -> ")
      required_app = List.last(app_path)
      case from_dep do
        nil ->
          {path_str, "=> #{required_app} is missing from #{Mix.Project.config[:app]}", String.length(path_str)}
        %Mix.Dep{} ->
          {path_str, "=> #{required_app} is missing from #{from_dep.app}", String.length(path_str)}
      end
    end)
    {_,_,pad_to} = Enum.max_by(apps, fn {_,_,len} -> len end)
    format_requirements(apps, Inspect.Algebra.empty, pad_to)
  end
  defp format_requirements([], doc, _pad_to) do
    doc
    |> Inspect.Algebra.nest(4 * 2)
    |> Inspect.Algebra.format(999)
  end
  defp format_requirements([{app, from, len}|apps], doc, pad_to) do
    glued = Inspect.Algebra.glue(pad_requirement(app, len, pad_to), from)
    doc   = Inspect.Algebra.line(doc, glued)
    format_requirements(apps, doc, pad_to)
  end
  defp pad_requirement(app, len, pad_to) do
    app <> String.duplicate(" ", pad_to - len)
  end

  # Flattens the dependency graph to show paths to individual missing applications
  defp get_missing_app_paths([], _acc), do: []
  defp get_missing_app_paths([{parent, []} | rest], acc) do
    [parent] ++ get_missing_app_paths(rest, acc)
  end
  defp get_missing_app_paths([{parent, children} | rest], acc) do
    result = get_missing_app_paths(children, [parent | acc])
    result ++ get_missing_app_paths(rest, acc)
  end
  defp get_missing_app_paths([app | rest], acc) when is_atom(app) do
    path = Enum.reverse([app | acc])
    [path | get_missing_app_paths(rest, acc)]
  end

  @doc """
  Returns a list of explict applications found in mix.exs :applications/:included_applications
  """
  def get_explicit_applications() do
    get_project_apps(Mix.Project.get!)
  end

  @doc """
  Returns a graph (represented as a nested keyword list) of implicitly included applications
  for the current project.
  """
  def get_implicit_applications(extras \\ []) do
    all_apps = get_included_applications()
    explicit = get_explicit_applications() ++ extras
    get_implicit_apps(explicit, all_apps, [])
  end

  @doc """
  Gets all applications and what applications they include.
  """
  def get_included_applications(), do: get_included_applications(Mix.Dep.loaded([]))
  def get_included_applications(deps) when is_list(deps) do
    deps
    |> Enum.map(&get_applications/1)
    |> List.flatten
    |> Enum.uniq
  end

  # Given a list of application names, and a list of all top_level applications,
  # this function builds a list of all applications which are implicitly included
  # in the release.
  defp get_implicit_apps([], _all_apps, acc), do: acc
  defp get_implicit_apps([app | rest], all_apps, acc) do
    case Keyword.get(all_apps, app, []) do
      []   -> get_implicit_apps(rest, all_apps, acc)
      apps ->
        case get_implicit_apps(apps, all_apps, []) do
          []      -> get_implicit_apps(rest, all_apps, [app | acc])
          subapps -> get_implicit_apps(rest, all_apps, [{app, subapps} | acc])
        end
    end
  end

  defp flatten_tree([]),   do: []
  defp flatten_tree(tree), do: flatten_tree(tree, [])
  defp flatten_tree([], acc), do: acc
  defp flatten_tree([element | rest], acc) when is_list(element), do: flatten_tree(rest, element++acc)
  defp flatten_tree([{parent, children} | rest], acc) do
    flatten_tree(rest, flatten_tree(children, [parent] ++ acc))
  end
  defp flatten_tree([element | rest], acc), do: flatten_tree(rest, [element | acc])

  # Gets applications for a given mix dependency
  defp get_applications(%Mix.Dep{app: app, manager: :mix, opts: opts}) do
    case is_dep_required?(opts) do
      false -> []
      true  ->
        project_dir = Keyword.get(opts, :dest)
        Mix.Project.in_project(app, project_dir, [], fn _ ->
          project_apps = get_project_apps(Mix.Project.get!)
          [{app, project_apps}]
        end)
    end
  end
  # Gets applications for a given rebar dependency
  defp get_applications(%Mix.Dep{app: app, manager: manager, opts: opts}) when manager in [:rebar, :make] do
    project_dir = Keyword.get(opts, :dest)
    case Path.wildcard(Path.join(project_dir, "**/#{app}.app.src")) do
      [] -> []
      [app_src_path|_] ->
        case ReleaseManager.Utils.read_terms(app_src_path) do
          [{:application, ^app, config}] ->
            apps     = Keyword.get(config, :applications, [])
            inc_apps = Keyword.get(config, :included_applications, [])
            [{app, apps ++ inc_apps}]
          _ ->
            []
        end
    end
  end
  defp get_applications(%Mix.Dep{}), do: []

  defp filter_dependency_tree(tree, fun),     do: filter_dependency_tree(tree, fun, [])
  defp filter_dependency_tree([], _fun, acc), do: acc
  defp filter_dependency_tree([dep | rest], fun, acc) when not is_tuple(dep) do
    case fun.(dep) do
      true  -> filter_dependency_tree(rest, fun, [dep | acc])
      false -> filter_dependency_tree(rest, fun, acc)
    end
  end
  defp filter_dependency_tree([{dep, children} | rest], fun, acc) do
    case fun.(dep) do
      true ->
        acc = [{dep, filter_dependency_tree(children, fun, [])} | acc]
        filter_dependency_tree(rest, fun, acc)
      false ->
        filter_dependency_tree(rest, fun, acc)
    end
  end

  defp map_dependency_tree(tree, fun),     do: map_dependency_tree(tree, fun, [])
  defp map_dependency_tree([], _fun, acc), do: acc
  defp map_dependency_tree([{dep, children} | rest], fun, acc) do
    acc = [{fun.(dep), map_dependency_tree(children, fun, [])} | acc]
    map_dependency_tree(rest, fun, acc)
  end
  defp map_dependency_tree([dep | rest], fun, acc) do
    map_dependency_tree(rest, fun, [fun.(dep) | acc])
  end


  # Loads the current project's dependency tree and returns it
  # as list of lists, where elements are either atoms (no children),
  # or key/value pairs (parent/children).
  defp get_dependency_tree(deps) do
    deps
    |> Enum.map(fn dep -> get_dependency_tree(dep, deps) end)
    |> List.flatten
  end
  defp get_dependency_tree(%Mix.Dep{app: a, deps: deps, top_level: true} = dep, all_deps) do
    if {:warn_missing, false} in dep.opts do
      []
    else
      [{a, get_dependency_tree(deps, all_deps, [])}]
    end
  end
  defp get_dependency_tree(%Mix.Dep{top_level: false}, _all_deps), do: []
  defp get_dependency_tree([], _all_deps, acc), do: acc
  defp get_dependency_tree([%Mix.Dep{app: a} | rest], all_deps, acc) do
    dep = Enum.find(all_deps, fn %Mix.Dep{app: app} -> app == a end)
    if {:warn_missing, false} in dep.opts do
      []
    else
      children = get_dependency_tree(dep.deps, all_deps, [])
      case children do
        [] -> get_dependency_tree(rest, all_deps, [dep.app | acc])
        _  -> get_dependency_tree(rest, all_deps, [{dep.app, children} | acc])
      end
    end
  end

  # Given the kwlist options from %Mix.Deps{opts: opts},
  # determine if this dependency is required for the current
  # environment
  defp is_dep_required?(opts) when is_list(opts) do
    case Keyword.get(opts, :only) do
      envs when is_list(envs) -> Mix.env in envs
      nil -> true
      env -> Mix.env == env
    end
  end

  defp get_project_apps(mixfile) when is_atom(mixfile) do
    exports = mixfile.module_info(:exports)
    cond do
      {:application, 0} in exports ->
        app_spec = mixfile.application
        Keyword.get(app_spec, :applications, []) ++ Keyword.get(app_spec, :included_applications, [])
      :else ->
        []
    end
  end

end
