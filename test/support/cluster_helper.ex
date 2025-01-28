defmodule ClusterHelper do
  import ExUnit.Assertions

  def apply_and_reply(test_pid, {m, f, a}) do
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

  def test_ancestors(test_pid) do
    grandparent = self()
    {_, great_grandparent} = Process.info(self(), :parent)
    assert node(great_grandparent) != node(self())

    Task.async(fn ->
      parent = self()

      Task.async(fn ->
        ancestors = ProcessTree.known_ancestors(self())
        assert ancestors == [parent, grandparent]
        send(test_pid, :done)
      end)
      |> Task.await()
    end)
    |> Task.await()
  end

  def test_get_parent(test_pid) do
    grandparent = self()

    Task.async(fn ->
      parent = self()

      Task.async(fn ->
        actual = ProcessTree.parent(self())
        assert actual == parent

        actual = ProcessTree.parent(actual)
        assert actual == grandparent

        send(test_pid, :done)
      end)
      |> Task.await()
    end)
    |> Task.await()
  end
end
