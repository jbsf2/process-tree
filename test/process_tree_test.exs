defmodule ProcessTreeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  setup context do
    line = Map.get(context, :line) |> Integer.to_string()
    Process.put(:process_name_prefix, line <> "-")
    :ok
  end

  test "genserver test" do
    Process.put(:foo, :bar)

    [
      start_genserver(self(), :gen1, :foo),
      start_genserver(self(), :gen2, :foo),
      start_genserver(self(), :gen3, :foo),
      start_genserver(self(), :gen4, :foo)
    ]
    |> execute()

    assert dict_value(:gen4) == :bar
  end

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

      [start_task(self(), :task, :foo)] |> execute()

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

    test "when an $ancestor process has died, it looks up to the next ancestor" do
      Process.put(:foo, :bar)

      [
        start_task(self(), :gen1),
        start_task(self(), :gen2, :foo)
      ]
      |> execute()

      kill(:gen1)

      assert dict_value(:gen2) == :bar
    end

    test "when multiple $ancestors have died, it keeps looking up" do
      Process.put(:foo, :bar)

      [
        start_task(self(), :gen1),
        start_task(self(), :gen2),
        start_task(self(), :gen3, :foo)
      ]
      |> execute()

      kill(:gen1)
      kill(:gen2)

      assert dict_value(:gen3) == :bar
    end

    @tag :otp25_or_later
    test "it works with a single spawn() ancestor" do
      Process.put(:foo, :bar)

      [spawn_process(self(), :gen1, :foo)] |> execute()

      assert dict_value(:gen1) == :bar
    end

    @tag :otp25_or_later
    test "it works with multiple spawn() ancestors" do
      Process.put(:foo, :bar)

      [
        spawn_process(self(), :gen1),
        spawn_process(self(), :gen2),
        spawn_process(self(), :gen3, :foo)
      ]
      |> execute()

      assert dict_value(:gen3) == :bar
    end
  end

  describe "finding ancestors" do
    @tag :otp25_or_later
    test "using plain spawn, can find all ancestors when they're all still alive" do
      [
        spawn_process(self(), :gen1),
        spawn_process(self(), :gen2),
        spawn_process(self(), :gen3)
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
        spawn_process(self(), :gen1),
        spawn_process(self(), :gen2),
        spawn_process(self(), :gen3)
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
        start_task(self(), :gen1),
        start_task(self(), :gen2),
        start_task(self(), :gen3)
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
        start_task(self(), :gen1),
        start_task(self(), :gen2)
      ]
      |> execute()

      gen1 = kill(:gen1)
      gen2 = pid(:gen2)

      assert ProcessTree.ancestor(gen2, 1) == gen1
      assert ProcessTree.ancestor(gen2, 2) == self()
    end

    test "using Task, when multiple intermediate ancestors have died, can find all ancestors" do
      [
        start_task(self(), :gen1),
        start_task(self(), :gen2),
        start_task(self(), :gen3),
        start_task(self(), :gen4),
      ]
      |> execute()

      kill(:gen1)
      kill(:gen2)
      kill(:gen3)

      gen4 = pid(:gen4)
      assert ProcessTree.ancestor(gen4, 4) == self()
    end
  end

  defp full_name(pid_name) do
    prefix = Process.get(:process_name_prefix)
    (prefix <> Atom.to_string(pid_name)) |> String.to_atom()
  end

  @spec dict_value(atom()) :: any()
  defp dict_value(pid_name) do
    pid = pid(pid_name)
    send(pid, :dict_value)

    full_name = full_name(pid_name)

    receive do
      {^full_name, :dict_value, value} ->
        value
    end
  end

  @spec kill(atom()) :: pid()
  defp kill(pid_name) do
    pid = pid(pid_name)
    ref = Process.monitor(pid)

    send(pid, :exit)

    receive do
      {:DOWN, ^ref, _, _, _} ->
        pid
    end
  end

  @spec kill_on_exit(atom()) :: :ok
  defp kill_on_exit(full_pid_name) do
    on_exit(fn ->
      pid = Process.whereis(full_pid_name)
      # process may already be dead
      if pid != nil do
        true = Process.exit(pid, :kill)
      end
    end)
  end

  @spec pid(atom()) :: pid()
  defp pid(pid_name) do
    full_name = full_name(pid_name)
    registered_pid = Process.whereis(full_name)

    pid =
      case registered_pid do
        nil ->
          receive do
            {^full_name, :pid, pid} ->
              pid
          end

        pid ->
          pid
      end

    receive do
      {^full_name, :ready} ->
        :ok
    end

    pid
  end

  @typep nestable_function :: (nestable_function() | nil -> {:ok, pid()})
  @typep spawnable_function :: (-> any())
  @typep spawner :: (spawnable_function() -> {:ok, pid()})

  @spec start_task(pid(), atom(), atom() | nil) :: nestable_function()
  defp start_task(test_pid, this_pid_name, dict_key \\ nil) do
    nestable_function(test_pid, this_pid_name, &Task.start/1, dict_key)
  end

  @spec spawn_process(pid(), atom(), atom() | nil) :: nestable_function()
  defp spawn_process(test_pid, this_pid_name, dict_key \\ nil) do
    spawner = fn spawnable_function ->
      pid = spawn(spawnable_function)
      {:ok, pid}
    end

    nestable_function(test_pid, this_pid_name, spawner, dict_key)
  end

  defp start_genserver(test_pid, name, dict_key) do
    full_name = full_name(name)
    kill_on_exit(full_name)

    fn next_function ->
      {:ok, pid} = GenServer.start(TestGenserver, {test_pid, next_function, dict_key, full_name}, name: full_name)
      :ok = GenServer.call(pid, :execute_next_function)
      send(test_pid, {full_name, :ready})
      {:ok, pid}
    end
  end

  @spec nestable_function(pid(), atom(), spawner(), atom() | nil) :: nestable_function()
  defp nestable_function(test_pid, this_pid_name, spawner, dict_key) do
    full_name = full_name(this_pid_name)
    kill_on_exit(full_name)

    fn next_function ->
      this_function = fn ->

        if next_function != nil, do: next_function.()

        send(test_pid, {full_name, :ready})

        if dict_key != nil do
          receive do
            :dict_value ->
              value = ProcessTree.get(dict_key)
              send(test_pid, {full_name, :dict_value, value})
          end
        end

        wait_for_exit()
      end

      {:ok, pid} = spawner.(this_function)
      true = Process.register(pid, full_name)
      send(test_pid, {full_name, :pid, pid})
    end
  end

  @spec wait_for_exit() :: :ok
  defp wait_for_exit() do
    receive do
      :exit -> :ok
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
