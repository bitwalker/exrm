defmodule ReleaseManager.Appups do
  @moduledoc """
  Module for generating auto-generating appups between releases.
  """
  import ReleaseManager.Utils, only: [info: 1, error: 1]

  def make_appup(application, v1, v2, v1_path, v2_path) do
    case :file.consult(v1_path ++ '/ebin/' ++ atom_to_list(application) ++ '.app') do
      { :ok, [ { :application, application, v1_props } ] } ->
        case vsn(v1_props) === v1 do
          true ->
            case :file.consult(v2_path ++ '/ebin/' ++ atom_to_list(application) ++ '.app') do
              { :ok, [ { :application, application, v2_props } ] } ->
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

  def make_appup(application, v1, v1_props, v2, v2_path, v2_props) do
    add_mods = modules(v2_props) -- modules(v1_props)
    del_mods = modules(v1_props) -- modules(v2_props)

    { up_version_change, down_version_change } =
      case start_module(v2_props) do
        { :ok, start_mod, start_args } ->
          start_mod_beam_file = v2_path ++ '/ebin/' ++ atom_to_list(start_mod) ++ '.beam'
          {
            (lc {:ok, beam} inlist :file.read_file(start_mod_beam_file),
               d           inlist version_change(beam, v1, start_mod, start_args),
            do: d),
            (lc {:ok, beam} inlist :file.read_file(start_mod_beam_file),
               d           inlist version_change(beam, {:down, v1}, start_mod, start_args),
            do: d)
          }
        :undefined ->
          { [], [] }
      end

    up_directives =
      (lc m          inlist modules(v2_props) -- add_mods,
         beam_file   inlist (v2_path ++ '/ebin/' ++ atom_to_list(m) ++ '.beam'),
         {:ok, beam} inlist :file.read_file(beam_file),
         d           inlist upgrade_directives(v1, v2, m, beam),
      do: d)

    down_directives = 
      (lc m          inlist :lists.reverse(modules(v2_props) -- add_mods),
         beam_file   inlist (v2_path ++ '/ebin' ++ atom_to_list(m) ++ '.beam'),
         {:ok, beam} inlist :file.read_file(beam_file),
         d           inlist downgrade_directives(v1, v2, m, beam),
      do: d)
      
    appup =
      { v2,
        [ { v1,
            (lc m inlist add_mods, do: { :add_module, m })
            ++ up_directives
            ++ up_version_change
            ++ (lc m inlist del_mods, do: { :delete_module, m })
          }
        ],
        [ { v1,
            (lc m inlist :lists.reverse(del_mods), do: { :add_module, m })
            ++ down_version_change
            ++ down_directives
            ++ (lc m inlist :lists.reverse(add_mods), do: { :delete_module, m })
          }
        ]
      }

    info "Generated .appup for #{application} #{v1} -> #{v2}"
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
        :lists.member({ func, arity }, exports)
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

  defp upgrade_directives(v1, v2, m, beam) do
    case is_supervisor(beam) do
      true ->
        upgrade_directives_supervisor(v1, v2, m, beam)
      false ->
        case has_code_change(beam) do
          true  -> [ { :update, m, :infinity, { :advanced, [] }, :brutal_purge, :brutal_purge, [] } ]
          false -> [ { :load_module, m } ]
        end
    end
  end

  defp upgrade_directives_supervisor(v1, v2, m, beam) do
    case beam_exports(beam, :sup_upgrade_notify, 2) do
      true ->
        [ { :update, m, :supervisor },
          { :apply, { m, :sup_upgrade_notify, [ v1, v2 ] } } ]
      false ->
        [ { :update, m, :supervisor } ]
    end
  end

  defp downgrade_directives(v1, v2, m, beam) do
    case is_supervisor(beam) do
      true ->
        downgrade_directives_supervisor(v1, v2, m, beam)
      false ->
        case has_code_change(beam) do
          true  -> [ { :update, m, :infinity, { :advanced, [] }, :brutal_purge, :brutal_purge, [] } ]
          false -> [ { :load_module, m } ]
        end
    end
  end

  defp downgrade_directives_supervisor(v1, v2, m, beam) do
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
    vsn
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