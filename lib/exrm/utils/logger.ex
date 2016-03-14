defmodule ReleaseManager.Utils.Logger do

  def configure(verbosity) when is_atom(verbosity) do
    Application.put_env(:exrm, :verbosity, verbosity)
  end

  @doc "Print an informational message without color"
  def debug(message),  do: log(:debug, "==> #{message}")
  @doc "Print an informational message in green"
  def info(message),   do: log(:info, "==> #{IO.ANSI.green}#{message}#{IO.ANSI.reset}")
  @doc "Print a warning message in yellow"
  def warn(message),   do: log(:warn, "==> #{IO.ANSI.yellow}#{message}#{IO.ANSI.reset}")
  @doc "Print a notice in yellow"
  def notice(message), do: log(:notice, "#{IO.ANSI.yellow}#{message}#{IO.ANSI.reset}")
  @doc "Print an error message in red"
  def error(message),  do: log(:error, "==> #{IO.ANSI.red}#{message}#{IO.ANSI.reset}")

  defp log(level, message), do: log(level, Application.get_env(:exrm, :verbosity, :normal), message)

  defp log(:error, :silent, message),     do: IO.puts message
  defp log(_level, :silent, _message),    do: :ok
  defp log(:debug, :quiet, _message),     do: :ok
  defp log(:debug, :normal, _message),    do: :ok
  defp log(:debug, _verbosity, message),  do: IO.puts message
  defp log(:info, :quiet, _message),      do: :ok
  defp log(:info, _verbosity, message),   do: IO.puts message
  defp log(_level, _verbosity, message),  do: IO.puts message

end
