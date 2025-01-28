defmodule ProcessTreeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ProcessTree.OtpRelease

  setup_all context do
    {:ok, supervisor} = Task.Supervisor.start_link()
    {:ok, supervisor2} = Task.Supervisor.start_link()
    {:ok, supervisor3} = Task.Supervisor.start_link()

    context
    |> Map.put(:supervisor, supervisor)
    |> Map.put(:supervisor2, supervisor2)
    |> Map.put(:supervisor3, supervisor3)
  end

  setup context do
    line = Map.get(context, :line) |> Integer.to_string()
    Process.put(:process_name_prefix, line <> "-")
    :ok
  end

  describe "process scenarios" do
    setup do
      Process.put(:foo, :bar)
      :ok
    end

    test "standard supervision tree" do
      [
        start_supervisor(self(), :gen1),
        link_supervisor(self(), :gen2),
        link_supervisor(self(), :gen3),
        link_genserver(self(), :gen4)
      ]
      |> execute()

      assert dict_value(:gen4, :foo) == :bar

      assert ancestors(:gen4, 4) == [
               pid(:gen3),
               pid(:gen2),
               pid(:gen1),
               self()
             ]
    end

    test "standard supervision tree, after supervisor restarts" do
      [
        start_supervisor(self(), :gen1),
        link_supervisor(self(), :gen2),
        link_supervisor(self(), :gen3),
        link_genserver(self(), :gen4)
      ]
      |> execute()

      original_pid = pid(:gen4)
      kill_supervisor(:gen3)
      new_pid = pid(:gen4)

      assert new_pid != original_pid
      assert dict_value(:gen4, :foo) == :bar

      assert ancestors(:gen4, 4) == [
               pid(:gen3),
               pid(:gen2),
               pid(:gen1),
               self()
             ]
    end

    test "with a single dead $ancestor" do
      [
        start_task(self(), :gen1),
        start_task(self(), :gen2)
      ]
      |> execute()

      gen1 = kill(:gen1)
      assert dict_value(:gen2, :foo) == :bar

      expected_gen1 =
        case OtpRelease.process_info_tracks_parent?() do
          true -> gen1
          false -> full_name(:gen1)
        end

      expected_ancestors =
        case ElixirRelease.task_spawned_by_proc_lib?() do
          true -> [expected_gen1, self()]
          false -> [gen1, self()]
        end

      assert ancestors(:gen2, 2) == expected_ancestors
    end

    test "with multiple dead $ancestors" do
      [
        start_task(self(), :gen1),
        start_task(self(), :gen2),
        start_task(self(), :gen3),
        start_task(self(), :gen4)
      ]
      |> execute()

      gen1 = kill(:gen1)
      gen2 = kill(:gen2)
      gen3 = kill(:gen3)

      assert dict_value(:gen4, :foo) == :bar

      expected_gen3 =
        case OtpRelease.process_info_tracks_parent?() do
          true -> gen3
          false -> full_name(:gen3)
        end

      expected_ancestors =
        case ElixirRelease.task_spawned_by_proc_lib?() do
          true ->
            [
              expected_gen3,
              full_name(:gen2),
              full_name(:gen1),
              self()
            ]

          false ->
            [
              gen3,
              gen2,
              gen1,
              self()
            ]
        end

      assert ancestors(:gen4, 4) == expected_ancestors
    end

    test "with dead ancestors who have registered names in $ancestors" do
      [
        start_genserver(self(), :gen1),
        start_genserver(self(), :gen2),
        start_genserver(self(), :gen3),
        start_genserver(self(), :gen4)
      ]
      |> execute()

      parent_pid = kill(:gen3)
      kill(:gen2)

      expected_parent =
        case OtpRelease.process_info_tracks_parent?() do
          true -> parent_pid
          false -> full_name(:gen3)
        end

      assert dict_value(:gen4, :foo) == :bar

      assert ancestors(:gen4, 4) == [
               expected_parent,
               full_name(:gen2),
               pid(:gen1),
               self()
             ]
    end

    @tag :otp25_or_later
    test "with a single spawn() ancestor, OTP 25+" do
      [spawn_process(self(), :gen1)] |> execute()

      assert dict_value(:gen1, :foo) == :bar
      assert ancestors(:gen1, 1) == [self()]
    end

    @tag :pre_otp25
    test "with a single spawn() ancestor, pre OTP 25" do
      [spawn_process(self(), :gen1)] |> execute()

      assert dict_value(:gen1, :foo) == nil
      assert ancestors(:gen1, 1) == []
    end

    @tag :otp25_or_later
    test "multiple spawn() ancestors, all still alive, OTP 25+" do
      [
        spawn_process(self(), :gen1),
        spawn_process(self(), :gen2),
        spawn_process(self(), :gen3)
      ]
      |> execute()

      assert dict_value(:gen3, :foo) == :bar

      assert ancestors(:gen3, 3) == [
               pid(:gen2),
               pid(:gen1),
               self()
             ]
    end

    @tag :pre_otp25
    test "multiple spawn() ancestors, all still alive, pre OTP 25" do
      [
        spawn_process(self(), :gen1),
        spawn_process(self(), :gen2),
        spawn_process(self(), :gen3)
      ]
      |> execute()

      assert dict_value(:gen3, :foo) == nil
      assert ancestors(:gen3, 3) == []
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

      assert dict_value(:gen3, :foo) == nil
      assert ancestors(:gen3, 3) == [gen2]
    end

    test "using Task, finds all ancestors when they're all still alive" do
      [
        start_task(self(), :gen1),
        start_task(self(), :gen2),
        start_task(self(), :gen3)
      ]
      |> execute()

      assert dict_value(:gen3, :foo) == :bar

      assert ancestors(:gen3, 3) == [
               pid(:gen2),
               pid(:gen1),
               self()
             ]
    end
  end

  describe "known_ancestors()" do
    @tag :otp25_or_later
    test "under OTP 25+, includes the :init pid as the last known ancestor" do
      ancestors = ProcessTree.known_ancestors(self())
      assert List.last(ancestors) == Process.whereis(:init)
    end
  end

  describe "parent()" do
    test "when the pid is the :init pid, returns :undefined" do
      init = Process.whereis(:init)
      assert ProcessTree.parent(init) == :undefined
    end

    test "when the pid has died, returns :unknown" do
      [spawn_process(self(), :gen1)] |> execute()
      pid = kill(:gen1)
      assert ProcessTree.parent(pid) == :unknown
    end

    @tag :pre_otp25
    test "when using earlier OTP, returns :unknown for 'spawn' processes" do
      [spawn_process(self(), :gen1)] |> execute()
      assert ProcessTree.parent(pid(:gen1)) == :unknown
    end
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
      Process.put(:foo, :bar)

      [start_task(self(), :task)] |> execute()

      assert dict_value(:task, :foo) == :bar
    end

    test "when a value is found, it ignores the default value" do
      Process.put(:foo, :bar)

      assert ProcessTree.get(:foo, default: :default_value) == :bar

      assert Process.get(:foo) == :bar
    end

    test "when a value is not found, it 'caches' the default value in the calling process's dictionary" do
      assert Process.get(:foo) == nil

      assert ProcessTree.get(:foo, default: :bar) == :bar

      assert Process.get(:foo) == :bar
    end

    test "when `cache: false`, the default value is not cached" do
      assert Process.get(:foo) == nil

      assert ProcessTree.get(:foo, default: :bar, cache: false) == :bar

      assert Process.get(:foo) == nil
    end

    test "by default, it caches the result" do
      [
        start_task(self(), :gen1),
        start_task(self(), :gen2)
      ]
      |> execute()

      Process.put(:foo, :bar)

      assert dict_value(:gen1, :foo) == :bar
      assert dict_value(:gen2, :foo) == :bar

      Process.put(:foo, :something_else)

      assert dict_value(:gen1, :foo) == :bar
      assert dict_value(:gen2, :foo) == :bar
    end

    test "when `cache: false`, it does not cache the result" do
      [
        start_task(self(), :gen1),
        start_task(self(), :gen2)
      ]
      |> execute()

      Process.put(:foo, :bar)

      assert dict_value(:gen1, :foo, false) == :bar
      assert dict_value(:gen2, :foo, false) == :bar

      Process.put(:foo, :something_else)

      assert dict_value(:gen1, :foo, false) == :something_else
      assert dict_value(:gen2, :foo, false) == :something_else
    end

    test "supports arbitrary keys" do
      Process.put({:some, :disparate, :key}, :bar)

      assert ProcessTree.get({:some, :disparate, :key}) == :bar

      assert Process.get({:some, :disparate, :key}) == :bar
    end

    test "if we encounter a remote PID, we stop walking the tree" do
      {:ok, _} = :net_kernel.start([:process_tree_test, :shortnames])
      {:ok, _pid, other_node} = :peer.start_link()
      true = Node.connect(other_node)

      # test_pid = self()

      fun = fn -> ProcessTreeTest.hello() end
      dbg(fun)
      Node.spawn_link(other_node, &ProcessTreeTest.hello/0)

      assert_receive :done
    end

    def hello do
      IO.puts("hello")
    end
  end

  describe "using $callers" do
    test "when the first caller has the dictionary key", %{supervisor: supervisor} do
      Process.put(:foo, :bar)
      exunit_pid = self()

      task =
        Task.Supervisor.async_nolink(supervisor, fn ->
          assert !ancestor?(self(), exunit_pid)
          assert ProcessTree.get(:foo) == :bar
        end)

      Task.await(task, 1000)
    end

    test "when the first caller doesn't have the key but one of its non-caller ancestors does", %{
      supervisor: supervisor
    } do
      Process.put(:foo, :bar)

      [
        start_task(self(), :gen1),
        start_task(self(), :gen2),
        start_task(self(), :gen3),
        supervise_task(self(), supervisor, :gen4)
      ]
      |> execute()

      # sanity check
      assert !ancestor?(:gen4, self())
      assert ancestor?(caller(:gen4), self())

      assert dict_value(:gen4, :foo) == :bar
    end

    test "prefers the ancestors of callers over the the callers of callers", %{
      supervisor: supervisor_not_started_by_test_pid
    } do
      Process.put(:foo, :bar)

      {:ok, supervisor_started_by_test_pid} = Task.Supervisor.start_link()

      [
        start_task(self(), :gen1),
        supervise_task(self(), supervisor_started_by_test_pid, :gen2),
        start_task(self(), :gen3),
        supervise_task(self(), supervisor_not_started_by_test_pid, :gen4)
      ]
      |> execute()

      set_dict_value(:gen1, :foo, :not_bar)

      # sanity check
      assert ancestor?(:gen2, self())
      assert !ancestor?(:gen2, :gen1)
      assert caller(:gen2) == pid(:gen1)
      assert dict_value(:gen1, :foo) == :not_bar

      assert dict_value(:gen4, :foo) == :bar
    end

    test "layers of callers", context do
      Process.put(:foo, :bar)

      supervisor1 = context[:supervisor]
      supervisor2 = context[:supervisor2]
      supervisor3 = context[:supervisor3]

      [
        supervise_task(self(), supervisor1, :gen1),
        supervise_task(self(), supervisor2, :gen2),
        supervise_task(self(), supervisor3, :gen3)
      ]
      |> execute()

      # sanity check
      assert !ancestor?(:gen3, self())
      assert caller?(:gen3, self())

      assert dict_value(:gen3, :foo) == :bar
    end
  end

  @spec full_name(atom()) :: atom()
  defp full_name(pid_name) do
    prefix = Process.get(:process_name_prefix)
    (prefix <> Atom.to_string(pid_name)) |> String.to_atom()
  end

  @spec ancestor?(pid() | atom(), pid() | atom()) :: boolean()
  defp ancestor?(descendent, potential_ancestor) do
    descendent_pid = pid(descendent)
    ancestor_pid = pid(potential_ancestor)
    ancestors(descendent_pid) |> Enum.member?(ancestor_pid)
  end

  @spec ancestors(pid()) :: [pid() | atom()]
  defp ancestors(pid) do
    ProcessTree.known_ancestors(pid)
  end

  @spec caller(atom()) :: pid() | nil
  defp caller(pid_name) do
    dict_value(pid_name, :"$callers") |> hd()
  end

  @spec callers(atom()) :: [pid()] | nil
  defp callers(pid_name) do
    dict_value(pid_name, :"$callers")
  end

  @spec caller?(atom(), pid() | atom()) :: boolean()
  defp caller?(descendent_name, potential_ancestor) do
    ancestor_pid = pid(potential_ancestor)
    callers(descendent_name) |> Enum.member?(ancestor_pid)
  end

  @spec dict_value(atom(), atom(), boolean()) :: any()
  defp dict_value(pid_name, dict_key, cache_result? \\ true) do
    pid = pid(pid_name)
    send(pid, {:dict_value, dict_key, cache_result?})

    full_name = full_name(pid_name)

    receive do
      {^full_name, :dict_value, value} ->
        value
    end
  end

  @spec set_dict_value(atom(), atom(), any()) :: any()
  defp set_dict_value(pid_name, key, value) do
    pid = pid(pid_name)
    send(pid, {:set_dict_value, key, value})
  end

  @spec ancestors(atom(), pos_integer()) :: [pid()]
  defp ancestors(pid_name, ancestor_count) do
    pid = pid(pid_name)

    ProcessTree.known_ancestors(pid)
    |> Enum.take(ancestor_count)
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

  @spec kill_supervisor(atom()) :: pid()
  defp kill_supervisor(pid_name) do
    full_name = full_name(pid_name)
    original_pid = pid(pid_name)

    true = Process.exit(original_pid, :kill)

    receive do
      {^full_name, :ready, new_pid} ->
        Process.put(new_pid, :ready)
        new_pid
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

  @spec pid(pid() | atom()) :: pid()
  defp pid(pid) when is_pid(pid) do
    pid
  end

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

    if Process.get(pid) != :ready do
      receive do
        {^full_name, :ready, ^pid} ->
          Process.put(pid, :ready)
          :ok
      end
    end

    pid
  end

  @typep child_spec :: Supervisor.child_spec()
  @typep nestable_function :: (nestable_function() | nil -> {:ok, pid()} | child_spec())
  @typep spawnable_function :: (-> any())
  @typep spawner :: (spawnable_function() -> {:ok, pid()})

  @spec start_task(pid(), atom()) :: nestable_function()
  defp start_task(test_pid, this_pid_name) do
    nestable_function(test_pid, this_pid_name, &Task.start/1)
  end

  @spec supervise_task(pid(), pid(), atom()) :: nestable_function()
  defp supervise_task(test_pid, supervisor, this_pid_name) do
    nestable_function(test_pid, this_pid_name, fn function ->
      task = Task.Supervisor.async_nolink(supervisor, function)
      {:ok, task.pid}
    end)
  end

  @spec spawn_process(pid(), atom()) :: nestable_function()
  defp spawn_process(test_pid, this_pid_name) do
    spawner = fn spawnable_function ->
      pid = spawn(spawnable_function)
      {:ok, pid}
    end

    nestable_function(test_pid, this_pid_name, spawner)
  end

  defp start_genserver(test_pid, name) do
    full_name = full_name(name)
    kill_on_exit(full_name)

    fn next_function ->
      {:ok, pid} = GenServer.start(TestGenserver, {test_pid, full_name}, name: full_name)
      send(test_pid, {full_name, :pid, pid})
      :ok = GenServer.call(pid, {:execute, next_function})
      send(test_pid, {full_name, :ready, pid})
      {:ok, pid}
    end
  end

  @spec link_genserver(pid(), atom()) :: nestable_function()
  defp link_genserver(test_pid, name) do
    full_name = full_name(name)
    kill_on_exit(full_name)

    fn next_function ->
      %{
        id: full_name,
        start: {TestGenserver, :start_link, [[test_pid, full_name, next_function]]}
      }
    end
  end

  @spec link_supervisor(pid(), atom()) :: nestable_function()
  defp link_supervisor(test_pid, name) do
    full_name = full_name(name)
    kill_on_exit(full_name)

    fn next_function ->
      %{
        id: full_name,
        start: {TestSupervisor, :start_link, [[test_pid, full_name, next_function]]}
      }
    end
  end

  @spec start_supervisor(pid(), atom()) :: nestable_function()
  defp start_supervisor(test_pid, name) do
    full_name = full_name(name)
    kill_on_exit(full_name)

    fn next_function ->
      {:ok, _pid} = TestSupervisor.start_link([test_pid, full_name, next_function])
    end
  end

  @spec nestable_function(pid(), atom(), spawner()) :: nestable_function()
  defp nestable_function(test_pid, this_pid_name, spawner) do
    full_name = full_name(this_pid_name)
    kill_on_exit(full_name)

    fn next_function ->
      this_function = fn ->
        if next_function != nil do
          {:ok, _pid} = next_function.()
        end

        send(test_pid, {full_name, :ready, self()})

        receive_command(test_pid, full_name)
      end

      {:ok, pid} = spawner.(this_function)
      true = Process.register(pid, full_name)
      send(test_pid, {full_name, :pid, pid})
      {:ok, pid}
    end
  end

  defp receive_command(test_pid, full_name) do
    receive do
      {:dict_value, dict_key, cache_result?} ->
        value = ProcessTree.get(dict_key, cache: cache_result?)
        send(test_pid, {full_name, :dict_value, value})
        receive_command(test_pid, full_name)

      {:set_dict_value, key, value} ->
        Process.put(key, value)
        receive_command(test_pid, full_name)

      :exit ->
        :ok
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
