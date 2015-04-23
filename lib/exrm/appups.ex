defmodule ReleaseManager.Appups do
  @moduledoc """
  Module for auto-generating appups between releases.
  """
  import ReleaseManager.Utils, only: [write_term: 2]

  @doc """
  Generate a .appup for the given application, start version, and upgrade version.

      ## Parameter information
      application: the application name as an atom
      v1:          the start version, such as "0.0.1"
      v2:          the upgrade version, such as "0.0.2"
      v1_path:     the path to the v1 artifacts (rel/<app>/lib/<app>-0.0.1)
      v2_path:     the path to the v2 artifacts (_build/prod/lib/<app>)

  """
  def make(application, v1, v2, v1_path, v2_path) do
    v1_release =
      v1_path
      |> Path.join("/ebin/")
      |> Path.join(Atom.to_string(application) <> ".app")
      |> String.to_char_list
    v2_release =
      v2_path
      |> Path.join("/ebin/")
      |> Path.join(Atom.to_string(application) <> ".app")
      |> String.to_char_list

    case :file.consult(v1_release) do
      { :ok, [ { :application, ^application, v1_props } ] } ->
        case vsn(v1_props) === v1 do
          true ->
            case :file.consult(v2_release) do
              { :ok, [ { :application, ^application, v2_props } ] } ->
                case vsn(v2_props) === v2 do
                  true ->
                    make_appup(application, v1, v1_props, v2, v2_path, v2_props)
                  false ->
                    { :error, :bad_new_appvsn }
                end
              _ ->
                { :error, :bad_new_appfile }
            end
          false ->
            { :error, :bad_old_appvsn }
        end
      _ ->
        { :error, :bad_old_appfile }
    end
  end

  defp make_appup(application, v1, v1_props, v2, v2_path, v2_props) do
    add_mods = modules(v2_props) -- modules(v1_props)
    del_mods = modules(v1_props) -- modules(v2_props)

    { up_version_change, down_version_change } =
      case start_module(v2_props) do
        { :ok, start_mod, start_args } ->
          start_mod_beam_file =
            v2_path
            |> Path.join("/ebin/")
            |> Path.join(Atom.to_string(start_mod) <> ".beam")
          { start_mod_beam_file |> File.read! |> version_change(v1, start_mod, start_args),
            start_mod_beam_file |> File.read! |> version_change({:down, v1}, start_mod, start_args) }
        :undefined ->
          { [], [] }
      end

    up_directives =
      (modules(v2_props) -- add_mods) |> Enum.map(fn module ->
        (v2_path <> "/ebin/" <> Atom.to_string(module) <> ".beam")
        |> File.read!
        |> upgrade_directives(v1, v2, module)
      end) |> List.flatten

    down_directives =
      Enum.reverse(modules(v2_props) -- add_mods) |> Enum.map(fn module ->
        (v2_path <> "/ebin/" <> Atom.to_string(module) <> ".beam")
        |> File.read!
        |> downgrade_directives(v1, v2, module)
      end) |> List.flatten

    appup =
      { v2 |> String.to_char_list,
        [ { v1 |> String.to_char_list,
            (for m <- add_mods, do: { :add_module, m })
            ++ up_directives
            ++ up_version_change
            ++ (for m <- del_mods, do: { :delete_module, m })
          }
        ],
        [ { v1 |> String.to_char_list,
            (for m <- :lists.reverse(del_mods), do: { :add_module, m })
            ++ down_version_change
            ++ down_directives
            ++ (for m <- :lists.reverse(add_mods), do: { :delete_module, m })
          }
        ]
      }

    # Save the appup to the upgrade's build directory
    v2_path
    |> Path.join("ebin")
    |> Path.join((application |> Atom.to_string) <> ".appup")
    |> write_term(appup)

    { :ok, appup }
  end

  defp version_change(beam, from, start_mod, start_args) do
    case has_version_change(beam) do
      true ->
        [ { :apply, { start_mod, :version_change, [ from, start_args ] } } ]
      false ->
        []
    end
  end

  defp has_version_change(beam) do
    beam_exports(beam, :version_change, 2)
  end

  defp beam_exports(beam, func, arity) do
    case :beam_lib.chunks(beam, [ :exports ]) do
      { :ok, { _, [ { :exports, exports } ] } } ->
        exports |> Enum.member?({ func, arity })
      _ ->
        false
    end
  end

  defp start_module(props) do
    case :lists.keysearch(:mod, 1, props) do
      { :value, { :mod, { start_mod, start_args } } } ->
        { :ok, start_mod, start_args }
      false ->
        :undefined
    end
  end

  defp modules(props) do
    { :value, { :modules, modules } } = :lists.keysearch(:modules, 1, props)
    modules
  end

  defp upgrade_directives(beam, v1, v2, m) do
    case is_supervisor(beam) do
      true ->
        upgrade_directives_supervisor(beam, v1, v2, m)
      false ->
        case has_code_change(beam) do
          true  -> [ { :update, m, { :advanced, [] } } ]
          false -> [ { :load_module, m } ]
        end
    end
  end

  defp upgrade_directives_supervisor(beam, v1, v2, m) do
    case beam_exports(beam, :sup_upgrade_notify, 2) do
      true ->
        [ { :update, m, :supervisor },
          { :apply, { m, :sup_upgrade_notify, [ v1, v2 ] } } ]
      false ->
        [ { :update, m, :supervisor } ]
    end
  end

  defp downgrade_directives(beam, v1, v2, m) do
    case is_supervisor(beam) do
      true ->
        downgrade_directives_supervisor(beam, v1, v2, m)
      false ->
        case has_code_change(beam) do
          true  -> [ { :update, m, { :advanced, [] } } ]
          false -> [ { :load_module, m } ]
        end
    end
  end

  defp downgrade_directives_supervisor(beam, v1, v2, m) do
    case beam_exports(beam, :sup_downgrade_notify, 2) do
      true ->
        [ {
            :apply, { m, :sup_downgrade_notify, [ v1, v2 ] }
          },
          {
            :update, m, :supervisor
          } ]
      false ->
        [ { :update, m, :supervisor } ]
    end
  end

  defp has_code_change(beam) do
    beam_exports(beam, :code_change, 3)
  end

  defp is_supervisor(beam) do
    case :beam_lib.chunks(beam, [ :attributes ]) do
      { :ok, { _, [ { :attributes, attr } ] } } ->
        has_element(attr, :behaviour, :supervisor) or has_element(attr, :behavior, :supervisor)
      _ ->
        false
    end
  end

  defp vsn(props) do
    { :value, { :vsn, vsn } } = :lists.keysearch(:vsn, 1, props)
    vsn |> List.to_string
  end

  defp has_element(attr, key, elem) do
    case :lists.keysearch(key, 1, attr) do
      { :value, { ^key, value } } ->
        :lists.member(elem, value)
      _ ->
        false
    end
  end
end
