defmodule Test.Mixfile do
  use Mix.Project

  def project do
    [ app: :test,
      version: "0.0.1",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [mod: { Test, [] },
     applications: [:stdlib, :kernel, :elixir]]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, git: "https://github.com/elixir-lang/foobar.git", tag: "0.1" }
  #
  # To specify particular versions, regardless of the tag, do:
  # { :barbat, "~> 0.1", github: "elixir-lang/barbat" }
  defp deps do
    [{:exrm, path: "../../../"},
     {:conform, "~> 1.0.0-pre", override: true},
     {:fake_project, path: "../fake_project"}]
  end
end
