defmodule Test.Supervisor do

  def start_link do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      worker(Test.Server, [])
    ]

    Supervisor.start_link(children, [strategy: :one_for_one, name: Test.Supervisor])
  end

end
