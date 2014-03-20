defmodule AppupsTest do
  use ExUnit.Case

  test "generates valid .appup file" do
    v1_path = Path.join([File.cwd!, "test", "testapp", "v1"])
    v2_path = Path.join([File.cwd!, "test", "testapp", "v2"])
    {:ok, appup} = ReleaseManager.Appups.make(:test, "0.0.1", "0.0.2", v1_path, v2_path)

    assert appup == expected_appup
  end

  defp expected_appup do
    {'0.0.2',
       [{'0.0.1',
         [{:load_module,Test},
          {:update,Test.Server,:infinity,
                  {:advanced,[]},
                  :brutal_purge,:brutal_purge,[]},
          {:update,Test.Supervisor,:supervisor}]}],
       [{'0.0.1',
         [{:update,Test.Supervisor,:supervisor},
          {:update,Test.Server,:infinity,
                  {:advanced,[]},
                  :brutal_purge,:brutal_purge,[]},
          {:load_module,:"Elixir.Test"}]}]}
  end
end