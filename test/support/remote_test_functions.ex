defmodule RemoteTestFunctions do

  def test_nested_get(test_pid) do
    Task.async(fn ->
      Task.async(fn ->
        assert ProcessTree.get(:random_key) == nil
        send(test_pid, :done)
      end)
      |> Task.await()
    end)
    |> Task.await()
  end

  def test_ancestors(test_pid) do
    {_, great_grandparent} = Process.info(self(), :parent)
    assert node(great_grandparent) != node(self())

    grandparent = self()

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
        assert ProcessTree.parent(self()) == parent
        assert ProcessTree.parent(parent) == grandparent
        assert ProcessTree.parent(grandparent) == :unknown

        send(test_pid, :done)
      end)
      |> Task.await()
    end)
    |> Task.await()
  end

  # importing ExUnit.Assertions led to unmanageable dialyzer errors
  # so using this custom function instead.
  defp assert(condition) do
    if !condition do
      raise "it failed"
    end
  end

end
