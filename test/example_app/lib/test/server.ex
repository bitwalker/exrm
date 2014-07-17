defmodule Test.Server do
  use GenServer

  def start_link() do
    :gen_server.start_link({:local, :test}, __MODULE__, [], [])
  end

  def init([]) do
    { :ok, [] }
  end

  def handle_call(:ping, _from, state) do
    { :reply, :v1, state}
  end

end
