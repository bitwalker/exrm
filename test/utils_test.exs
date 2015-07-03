defmodule UtilsTest do
  use ExUnit.Case, async: true

  import PathHelpers

  alias ReleaseManager.Utils

  @example_app_path fixture_path("example_app")
  @old_path         fixture_path("configs/old_relx.config")
  @new_path         fixture_path("configs/new_relx.config")
  @expected_path    fixture_path("configs/merged_relx.config")

  defmacrop with_app(body) do
    quote do
      cwd = File.cwd!
      File.cd! @example_app_path
      unquote(body)
      File.cd! cwd
    end
  end

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

  test "can run a function in a specific Mix environment" do
    execution_env = Utils.with_env :prod, fn -> Mix.env end
    assert :prod = execution_env
  end

  test "can load the current project configuration for a given environment" do
    with_app do
      [test: config] = Utils.load_config(:prod)
      assert List.keymember?(config, :foo, 0)
    end
  end

  test "can invoke mix to perform a task for a given environment" do
    with_app do
      assert :ok = Utils.mix("clean", :prod)
    end
  end

  test "can get the current elixir library path" do
    path        = Path.join(Utils.get_elixir_lib_path, "../bin/elixir")
    {result, _} = System.cmd(path, ["--version"])
    version     = result |> String.strip(?\n)
    assert "Elixir #{System.version}" == version
  end

  @tag :expensive
  @tag timeout: 120000 # 120s
  test "can build a release and boot it up" do
    with_app do
      # Build release
      assert :ok = Utils.mix("do deps.get, compile", Mix.env, :verbose)
      assert :ok = Utils.mix("release", Mix.env)
      assert [{"test", "0.0.1"}] == Utils.get_releases("test")
      # Boot it, ping it, and shut it down
      bin_path = Path.join([File.cwd!, "rel", "test", "bin", "test"])
      assert {_, 0}        = System.cmd(bin_path, ["start"])
      :timer.sleep(1000) # Required, since starting up takes a sec
      assert {"pong\n", 0} = System.cmd(bin_path, ["ping"])
      assert {"ok\n", 0}   = System.cmd(bin_path, ["stop"])
    end
  end

  test "can compare semver versions" do
    assert ["1.0.10"|_] = Utils.sort_versions(["1.0.1", "1.0.2", "1.0.9", "1.0.10"])
  end

  test "can compare non-semver versions" do
    assert ["1.3", "1.2", "1.1"] = Utils.sort_versions(["1.1", "1.3", "1.2"])
  end

end
