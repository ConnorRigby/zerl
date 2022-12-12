defmodule MyServerTest do
  def recv do
    receive do
      {:"$gen_call", {pid, tag} = from, call} ->
        IO.puts "got call"
        send pid, {tag, :ok}
        recv()
      err -> raise("unexpected message: #{err}")
    end
  end
end
