defmodule ProcessTreeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  # In the tests below, Task is used as a representative for all the process types
  # that track $ancestors - Agent, GenServer, Supervisor and Task. If it works for Task,
  # it works for the others.

  describe "get()" do
    test "returns nil if there is no value found" do
      assert ProcessTree.get(:foo) == nil
    end

    test "when a value is set in the calling process' dictionary, it returns the value" do
      Process.put(:foo, :bar)
      assert ProcessTree.get(:foo) == :bar
    end

    test "when a value is set in the parent process' dictionary, it returns the value" do
      Process.put(:foo, :bar_from_parent)

      [task_function(self(), :task, :foo)] |> execute()

      assert dict_value(:task) == :bar_from_parent
    end

    test "when a value is not found, it 'caches' the default value in the calling process's dictionary" do
      assert Process.get(:foo) == nil

      assert ProcessTree.get(:foo, default: :bar) == :bar

      assert Process.get(:foo) == :bar
    end

    test "when a value is found, it ignores the default value" do
      Process.put(:foo, :bar)

      assert ProcessTree.get(:foo, default: :default_value) == :bar

      assert Process.get(:foo) == :bar
    end

    test "when an ancestor process has died, it looks up to the next ancestor" do
      Process.put(:foo, :bar)

      [
        task_function(self(), :gen1),
        task_function(self(), :gen2, :foo)
      ]
      |> execute()

      kill(:gen1)

      assert dict_value(:gen2) == :bar
    end

    test "multiple dead ancestors" do
      Process.put(:foo, :bar)

      [
        task_function(self(), :gen1),
        task_function(self(), :gen2),
        task_function(self(), :gen3, :foo)
      ]
      |> execute()

      kill(:gen1)
      kill(:gen2)

      assert dict_value(:gen3) == :bar
    end
  end

  describe "finding ancestors" do
    @tag :otp25_or_later
    test "using plain spawn, can find all ancestors when they're all still alive" do
      [
        spawn_function(self(), :gen1),
        spawn_function(self(), :gen2),
        spawn_function(self(), :gen3)
      ]
      |> execute()

      gen1 = pid(:gen1)
      gen2 = pid(:gen2)
      gen3 = pid(:gen3)

      assert ProcessTree.ancestor(gen3, 1) == gen2
      assert ProcessTree.ancestor(gen3, 2) == gen1
      assert ProcessTree.ancestor(gen3, 3) == self()
    end

    @tag :otp25_or_later
    test "using plain spawn, can't see beyond a dead ancestor" do
      [
        spawn_function(self(), :gen1),
        spawn_function(self(), :gen2),
        spawn_function(self(), :gen3)
      ]
      |> execute()

      gen2 = kill(:gen2)
      gen3 = pid(:gen3)

      assert ProcessTree.ancestor(gen3, 1) == gen2
      assert ProcessTree.ancestor(gen3, 2) == :unknown
      assert ProcessTree.ancestor(gen3, 3) == :unknown
    end

    test "using Task, finds all ancestors when they're all still alive" do
      [
        task_function(self(), :gen1),
        task_function(self(), :gen2),
        task_function(self(), :gen3)
      ]
      |> execute()

      gen1 = pid(:gen1)
      gen2 = pid(:gen2)
      gen3 = pid(:gen3)

      assert ProcessTree.ancestor(gen3, 1) == gen2
      assert ProcessTree.ancestor(gen3, 2) == gen1
      assert ProcessTree.ancestor(gen3, 3) == self()
    end

    test "using Task, when one intermediate ancestor has died, can find all ancestors" do
      [
        task_function(self(), :gen1),
        task_function(self(), :gen2)
      ]
      |> execute()

      gen1 = kill(:gen1)
      gen2 = pid(:gen2)

      assert ProcessTree.ancestor(gen2, 1) == gen1
      assert ProcessTree.ancestor(gen2, 2) == self()
    end

    test "using Task, when multiple intermediate ancestors have died, can find all ancestors" do
      [
        task_function(self(), :gen1),
        task_function(self(), :gen2),
        task_function(self(), :gen3)
      ]
      |> execute()

      kill(:gen1)
      kill(:gen2)

      gen3 = pid(:gen3)
      assert ProcessTree.ancestor(gen3, 3) == self()
    end
  end

  @spec dict_value(atom()) :: any()
  def dict_value(pid_name) do
    pid = pid(pid_name)
    send(pid, :dict_value)

    receive do
      {^pid_name, :dict_value, value} ->
        value
    end
  end

  @spec kill(atom()) :: pid()
  defp kill(pid_name) do
    pid = pid(pid_name)
    true = Process.exit(pid, :kill)
    pid
  end

  @spec pid(atom()) :: pid()
  defp pid(pid_name) do
    registered_pid = Process.whereis(pid_name)

    case registered_pid do
      nil ->
        receive do
          {^pid_name, :pid, pid} ->
            true = Process.register(pid, pid_name)
            pid
        end

      pid ->
        pid
    end
  end

  @typep nestable_function :: (nestable_function() | nil -> {:ok, pid()})
  @typep spawnable_function :: (-> any())
  @typep spawner :: (spawnable_function() -> {:ok, pid()})

  @spec task_function(pid(), atom(), atom() | nil) :: nestable_function()
  defp task_function(test_pid, this_pid_name, dict_key \\ nil) do
    nestable_function(test_pid, this_pid_name, &Task.start/1, dict_key)
  end

  @spec spawn_function(pid(), atom(), atom() | nil) :: nestable_function()
  defp spawn_function(test_pid, this_pid_name, dict_key \\ nil) do
    spawner = fn spawnable_function ->
      pid = spawn(spawnable_function)
      {:ok, pid}
    end

    nestable_function(test_pid, this_pid_name, spawner, dict_key)
  end

  @spec nestable_function(pid(), atom(), spawner(), atom() | nil) :: nestable_function()
  defp nestable_function(test_pid, this_pid_name, spawner, dict_key) do
    on_exit(fn ->
      pid = Process.whereis(this_pid_name)

      if pid != nil do
        true = Process.exit(pid, :kill)
      end
    end)

    fn next_function ->
      this_function = fn ->
        send(test_pid, {this_pid_name, :pid, self()})
        if next_function != nil, do: next_function.()

        if dict_key != nil do
          receive do
            :dict_value ->
              value = ProcessTree.get(dict_key)
              send(test_pid, {this_pid_name, :dict_value, value})
          end
        end

        stop()
      end

      spawner.(this_function)
    end
  end

  @spec stop() :: :ok
  defp stop() do
    receive do
      :stop -> :ok
    end
  end

  @spec execute([nestable_function()]) :: any()
  defp execute(functions) do
    nested_function = nest(functions)
    nested_function.()
  end

  @spec nest([nestable_function()]) :: spawnable_function()
  defp nest([last_function]), do: fn -> last_function.(nil) end

  defp nest(functions) do
    [this_function | later_functions] = functions
    next_function = nest(later_functions)

    fn ->
      this_function.(next_function)
    end
  end
end
