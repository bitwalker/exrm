defmodule ReleaseManager.Config do
  @moduledoc """
  Configuration for the release task.

  Contains the following values:

      name:      The name of your application
      version:   The version of your application
      dev?:      Is this release being built in dev mode
      env:       The mix environment the app should be build for
      erl:       The binary containing all options to pass to erl
      upgrade?:  Is this release an upgrade?
      verbosity: The verbosity level, one of [silent|quiet|normal|verbose]
      package:   Path to the generated release package.

  """
  defstruct name:      "",
            version:   "",
            dev:       false,
            env:       :prod,
            erl:       "",
            upgrade?:  false,
            verbosity: :quiet,
            relx_config: [],
            package:   nil
end
