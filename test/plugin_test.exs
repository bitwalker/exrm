defmodule PluginTest do
  use ExUnit.Case, async: true

  test "can fetch a list of plugins" do
    active = [
      ReleaseManager.Plugin.Consolidation,
      ReleaseManager.Plugin.Conform
    ] |> Enum.sort

    assert active == ReleaseManager.Plugin.load_all |> Enum.sort
  end
end