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
                    make_appup(application, v1, v1_path, v1_props, v2, v2_path, v2_props)
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

  defp make_appup(application, v1, v1_path, v1_props, v2, v2_path, v2_props) do
    {only_v1, only_v2, different} =
      :beam_lib.cmp_dirs(to_char_list(Path.join(v1_path, "ebin")), to_char_list(Path.join(v2_path, "ebin")))

    appup =
      { v2 |> String.to_char_list,
        [ { v1 |> String.to_char_list,
            (for file <- only_v2, do: generate_instruction(:added, file)) ++
            (for {file, _} <- different, do: generate_instruction(:changed, file)) ++
            (for file <- only_v1, do: generate_instruction(:deleted, file))
          }
        ],
        [ { v1 |> String.to_char_list,
            (for file <- only_v2, do: generate_instruction(:deleted, file)) ++
            (for {file, _} <- different, do: generate_instruction(:changed, file)) ++
            (for file <- only_v1, do: generate_instruction(:added, file))
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

  defp generate_instruction(:added, file) do
    {:add_module, module_name(file)}
  end

  defp generate_instruction(:deleted, file) do
    {:delete_module, module_name(file)}
  end

  defp generate_instruction(:changed, file) do
    {:ok, {module_name, list}} = :beam_lib.chunks(file, [:attributes, :exports])
    behaviour = get_in(list, [:attributes, :behavior]) || get_in(list, [:attributes, :behaviour])
    is_code_change = get_in(list, [:exports, :code_change]) != nil
    generate_instruction_advanced(module_name, behaviour, is_code_change)
  end

  defp generate_instruction_advanced(module_name, [:supervisor], _) do
    # supervisor
    {:update, module_name, :supervisor}
  end
  defp generate_instruction_advanced(module_name, _behaviour, true) do
    # exports code_change
    {:update, module_name, {:advanced, []}}
  end
  defp generate_instruction_advanced(module_name, _behaviour, false) do
    # code_change not exported
    {:load_module, module_name}
  end

  defp module_name(file) do
    :beam_lib.info(file) |> Keyword.fetch!(:module)
  end

  defp beam_exports(beam, func, arity) do
    case :beam_lib.chunks(beam, [ :exports ]) do
      { :ok, { _, [ { :exports, exports } ] } } ->
        exports |> Enum.member?({ func, arity })
      _ ->
        false
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
