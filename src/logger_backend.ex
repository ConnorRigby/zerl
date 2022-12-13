defmodule Zerl.LoggerBackend do
  def init(_) do
    Node.connect(:"zig@127.0.0.1")
    {:ok, %{}}
  end

  def handle_event({_level, _gl, {Logger, _, _, _}} = log, state) do
    IO.inspect(log)
    GenServer.cast({__MODULE__, :"zig@127.0.0.1"}, log)
    {:ok, state}
  end
end
