defmodule Mix.Tasks.Release do
  @moduledoc """
  Build a release for the current mix application.

  ## Examples

    mix release
    mix release clean

  """
  @shortdoc "Build a release for the current mix application."

  use Mix.Task

  def run(args) do
    # Ensure this isn't an umbrella project
    if Mix.Project.umbrella? do
      raise Mix.Error, message: "Umbrella projects are not currently supported!"
    end
    # Collect release configuration
    config = [ relfiles_path: Path.join([__DIR__, "..", "..", "..", "priv"]) |> Path.expand,
               project_name:  Mix.project |> Keyword.get(:app) |> atom_to_binary,
               project_ver:   Mix.project |> Keyword.get(:version) ]
    cond do
      # Clean up all release-related files
      "clean" in args ->
        makefile = Path.join(File.cwd!, "Makefile")
        if File.exists?(makefile) do
          File.rm!(makefile)
        end
      # Generate a release
      true ->
        config
        |> ensure_makefile
        |> ensure_relx_config
        |> ensure_runner
        |> execute_release
      end
  end

  defp ensure_makefile([{:relfiles_path, relfiles_path}, {:project_name, project} | _] = config) do
    source = Path.join(relfiles_path, "Makefile")
    # Destination is the root
    dest   = Path.join(File.cwd!, "Makefile")
    case File.exists?(dest) do
      # If the makefile has already been generated, skip generation
      true ->
        # Return the project config after we're done
        config
      # Otherwise, read in Makefile, replace the placeholders, and write it to the project root
      _ ->
        contents = File.read!(source) |> String.replace("{{{PROJECT_NAME}}}", project)
        File.write!(dest, contents)
        # Return the project options after we're done
        config
    end
  end

  defp ensure_relx_config(config) do
    config
  end

  defp ensure_runner(config) do
    config
  end

  defp execute_release(config) do
    config
  end

end