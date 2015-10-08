defmodule ReleaseManager.Utils.Logger do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, %{verbosity: :normal}, name: __MODULE__)
  end

  def configure(verbosity) when is_atom(verbosity) do
    GenServer.cast(__MODULE__, {:configure, verbosity})
  end

  @doc "Print an informational message without color"
  def debug(message), do: GenServer.cast(__MODULE__, {:log, :debug, message})
  @doc "Print an informational message in green"
  def info(message),  do: GenServer.cast(__MODULE__, {:log, :info, message})
  @doc "Print a warning message in yellow"
  def warn(message),  do: GenServer.cast(__MODULE__, {:log, :warn, message})
  @doc "Print a notice in yellow"
  def notice(message), do: GenServer.cast(__MODULE__, {:log, :notice, message})
  @doc "Print an error message in red"
  def error(message), do: GenServer.cast(__MODULE__, {:log, :error, message})

  def handle_cast({:configure, verbosity}, config) do
    {:noreply, %{config | :verbosity => verbosity}}
  end

  def handle_cast({:log, :error, message}, config) do
    print_error(message)
    {:noreply, config}
  end
  def handle_cast({:log, :warn, message}, %{verbosity: v} = config)
    when v in [:quiet, :normal, :verbose] do
    print_warn(message)
    {:noreply, config}
  end
  def handle_cast({:log, :notice, message}, %{verbosity: v} = config)
    when v in [:normal, :verbose] do
    print_notice(message)
    {:noreply, config}
  end
  def handle_cast({:log, :info, message}, %{verbosity: v} = config)
    when v in [:normal, :verbose] do
    print_info(message)
    {:noreply, config}
  end
  def handle_cast({:log, :debug, message}, %{verbosity: :verbose} = config) do
    print_debug(message)
    {:noreply, config}
  end
  def handle_cast({:log, :debug, _}, config) do
    {:noreply, config}
  end

  defp print_debug(message),  do: IO.puts "==> #{message}"
  defp print_info(message),   do: IO.puts "==> #{IO.ANSI.green}#{message}#{IO.ANSI.reset}"
  defp print_warn(message),   do: IO.puts "==> #{IO.ANSI.yellow}#{message}#{IO.ANSI.reset}"
  defp print_notice(message), do: IO.puts "#{IO.ANSI.yellow}#{message}#{IO.ANSI.reset}"
  defp print_error(message),  do: IO.puts "==> #{IO.ANSI.red}#{message}#{IO.ANSI.reset}"


end
