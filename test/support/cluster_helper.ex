defmodule ClusterHelper do
  require ExUnit.Assertions

  def apply_and_reply(test_pid, {m,f,a}) do
    apply(m, f, a)
    send(test_pid, :done)
  end

  def nested_get(test_pid) do
    Task.async(fn ->
      ProcessTree.get(:random_key)
      send(test_pid, :done)
     end)
     |> Task.await()
  end

  def ancestors(test_pid) do
    _grandparent = self() |> dbg()
    _great_grandparent = Process.info(self(), :parent) |> dbg()
    Task.async(fn ->
      _parent = self() |> dbg()
      Task.async(fn ->
        ancestors = ProcessTree.known_ancestors(self())
        dbg(ancestors)
        send(test_pid, {:done, ancestors})
      end)
      |> Task.await()
     end)
     |> Task.await()
  end
end
