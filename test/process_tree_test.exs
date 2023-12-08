defmodule ProcessTreeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule ProcessTreeTest.DummyGenServer do
    @moduledoc false
    use GenServer

    def start(_), do: GenServer.start(__MODULE__, [])
    def start_link(_), do: GenServer.start_link(__MODULE__, [])
    def get(key, pid), do: GenServer.call(pid, {:get, key})

    @impl true
    def init(_args), do: {:ok, %{}}

    @impl true
    def handle_call({:get, key}, _from, state) do
      value = ProcessTree.get_dictionary_value(key)
      {:reply, value, state}
    end
  end

  alias ProcessTreeTest.DummyGenServer

  test "returns nil if there is no value found" do
    assert ProcessTree.get_dictionary_value(:foo) == nil
  end

  test "when a value is set in the calling process' dictionary, it returns the value" do
    Process.put(:foo, :bar)
    assert ProcessTree.get_dictionary_value(:foo) == :bar
  end

  test "when a value is set in the parent process' dictionary, it returns the value" do
    Process.put(:foo, :bar_from_parent)
    {:ok, pid} = DummyGenServer.start_link([])
    assert DummyGenServer.get(:foo, pid) == :bar_from_parent
  end

  test "when a value is not found, it 'caches' the default value in the calling process's dictionary" do
    assert Process.get(:foo) == nil

    assert ProcessTree.get_dictionary_value(:foo, default: :bar) == :bar

    assert Process.get(:foo) == :bar
  end

  test "when a value is found, it ignores the default value" do
    Process.put(:foo, :bar)

    assert ProcessTree.get_dictionary_value(:foo, default: :default_value) == :bar

    assert Process.get(:foo) == :bar
  end

  test "when an ancestor process has died, it looks up to the next ancestor" do
    Process.put(:foo, :bar)

    task = Task.async(fn -> DummyGenServer.start([]) end)
    {:ok, genserver_pid} = Task.await(task)
    true = Process.exit(task.pid, :kill)

    assert DummyGenServer.get(:foo, genserver_pid) == :bar

    true = Process.exit(genserver_pid, :kill)
  end

  test "multiple dead ancestors" do
    Process.put(:foo, :bar)

    grandparent =
      Task.async(fn ->
        parent = Task.async(fn -> DummyGenServer.start([]) end)
        {:ok, genserver_pid} = Task.await(parent)
        true = Process.exit(parent.pid, :kill)
        {:ok, genserver_pid}
      end)

    {:ok, genserver_pid} = Task.await(grandparent)

    true = Process.exit(grandparent.pid, :kill)

    assert DummyGenServer.get(:foo, genserver_pid) == :bar

    true = Process.exit(genserver_pid, :kill)
  end
end
