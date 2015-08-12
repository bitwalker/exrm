defmodule PluginTest do
  use ExUnit.Case
  alias ReleaseManager.Utils

  test "can fetch a list of plugins" do
    active = [
      ReleaseManager.Plugin.Appups,
      ReleaseManager.Plugin.Consolidation,
      ReleaseManager.Plugin.Conform
    ] |> Enum.sort

    assert :ok = Utils.mix("do deps.get, compile", Mix.env, :quiet)
    assert active == ReleaseManager.Plugin.load_all |> Enum.sort
  end
end
