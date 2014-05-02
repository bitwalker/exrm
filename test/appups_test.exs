defmodule AppupsTest do
  use ExUnit.Case

  import ReleaseManager.Utils, only: [write_term: 2]

  @v1_path Path.join([File.cwd!, "test", "testapp", "v1", "ebin", "test.app"])
  @v2_path Path.join([File.cwd!, "test", "testapp", "v2", "ebin", "test.app"])

  setup do
    @v1_path |> write_term(v1_app)
    @v2_path |> write_term(v2_app)
    :ok
  end

  test "generates valid .appup file" do
    v1_path = Path.join([File.cwd!, "test", "testapp", "v1"])
    v2_path = Path.join([File.cwd!, "test", "testapp", "v2"])
    {:ok, appup} = ReleaseManager.Appups.make(:test, "0.0.1", "0.0.2", v1_path, v2_path)

    assert appup == expected_appup
  end

  teardown _meta do
    if @v1_path |> File.exists? do
      @v1_path |> File.rm!
    end
    if @v2_path |> File.exists? do
      @v2_path |> File.rm!
    end
    :ok
  end

  defp v1_app do
    {:application,:test,
             [{:registered,[]},
              {:description,'test'},
              {:mod,{:"Elixir.Test",[]}},
              {:applications,[:stdlib,:kernel,:elixir]},
              {:vsn,'0.0.1'},
              {:modules,[:"Elixir.Test",:"Elixir.Test.Server",
                         :"Elixir.Test.Supervisor"]}]}
  end

  defp v2_app do
    {:application,:test,
             [{:registered,[]},
              {:description,'test'},
              {:mod,{:"Elixir.Test",[]}},
              {:applications,[:exirc]},
              {:vsn,'0.0.2'},
              {:modules,[:"Elixir.Test",:"Elixir.Test.Server",
                         :"Elixir.Test.Supervisor"]}]}
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