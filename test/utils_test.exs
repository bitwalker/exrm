defmodule UtilsTest do
  use ExUnit.Case

  alias ReleaseManager.Utils

  @old_path      Path.join([File.cwd!, "test", "configs", "old_relx.config"])
  @new_path      Path.join([File.cwd!, "test", "configs", "new_relx.config"])
  @expected_path Path.join([File.cwd!, "test", "configs", "merged_relx.config"])

  test "can merge two relx.config files" do
    old      = @old_path |> Utils.read_terms
    new      = @new_path |> Utils.read_terms
    expected = @expected_path |> Utils.read_terms

    merged = Utils.merge(old, new)

    assert expected == merged
  end

  test "can read terms from string" do
    config   = @expected_path |> File.read!
    expected = @expected_path |> Utils.read_terms
    terms    = Utils.string_to_terms(config)

    assert expected == terms
  end
end