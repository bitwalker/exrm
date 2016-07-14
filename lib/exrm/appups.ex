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

  defp make_appup(application, v1, v1_path, _v1_props, v2, v2_path, _v2_props) do
    {only_v1, only_v2, different} =
      :beam_lib.cmp_dirs(to_char_list(Path.join(v1_path, "ebin")), to_char_list(Path.join(v2_path, "ebin")))

    appup =
      { v2 |> String.to_char_list,
        [ { v1 |> String.to_char_list,
            (for file <- only_v2, do: generate_instruction(:added, file)) ++
            (for {v1_file, v2_file} <- different, do: generate_instruction(:changed, {v1_file, v2_file})) ++
            (for file <- only_v1, do: generate_instruction(:deleted, file))
          }
        ],
        [ { v1 |> String.to_char_list,
            (for file <- only_v2, do: generate_instruction(:deleted, file)) ++
            (for {v1_file, v2_file} <- different, do: generate_instruction(:changed, {v1_file, v2_file})) ++
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

  defp generate_instruction(:added, file),   do: {:add_module, module_name(file)}
  defp generate_instruction(:deleted, file), do: {:delete_module, module_name(file)}
  defp generate_instruction(:changed, {v1_file, v2_file}) do
    module_name     = module_name(v1_file)
    attributes      = beam_attributes(v1_file)
    exports         = beam_exports(v1_file)
    is_supervisor   = is_supervisor?(attributes)
    is_special_proc = is_special_process?(exports)
    generate_instruction_advanced(module_name, is_supervisor, is_special_proc)
  end

  defp beam_attributes(file) do
    {:ok, {_, [attributes: attributes]}} = :beam_lib.chunks(file, [:attributes])
    attributes
  end

  defp beam_imports(file) do
    {:ok, {_, [imports: imports]}} = :beam_lib.chunks(file, [:imports])
    imports
  end

  defp beam_exports(file) do
    {:ok, {_, [exports: exports]}} = :beam_lib.chunks(file, [:exports])
    exports
  end

  defp is_special_process?(exports) do
    Keyword.get(exports, :system_code_change) == 4 ||
    Keyword.get(exports, :code_change) == 3
  end

  defp is_supervisor?(attributes) do
    behaviours = Keyword.get(attributes, :behavior, []) ++
                 Keyword.get(attributes, :behaviour, [])
    (:supervisor in behaviours) || (Supervisor in behaviours)
  end

  # supervisor
  defp generate_instruction_advanced(m, true, _is_special), do: {:update, m, :supervisor}
  # special process (i.e. exports code_change/3 or system_code_change/4)
  defp generate_instruction_advanced(m, _is_sup, true),     do: {:update, m, {:advanced, []}}
  # non-special process (i.e. neither code_change/3 nor system_code_change/4 are exported)
  defp generate_instruction_advanced(m, _is_sup, false),    do: {:load_module, m}

  defp module_name(file) do
    :beam_lib.info(file) |> Keyword.fetch!(:module)
  end

  defp vsn(props) do
    { :value, { :vsn, vsn } } = :lists.keysearch(:vsn, 1, props)
    vsn |> List.to_string
  end

end
