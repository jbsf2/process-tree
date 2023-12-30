defmodule TestGenserver do
  use GenServer

  defstruct [
    :test_pid,
    :next_function,
    :dict_key,
    :name
  ]

  def init({test_pid, next_function, dict_key, name}) do
    state = %__MODULE__{
      test_pid: test_pid,
      next_function: next_function,
      dict_key: dict_key,
      name: name
    }

    {:ok, state}
  end

  def handle_call(:execute_next_function, _from, state) do
    if state.next_function != nil do
      state.next_function.()
    end

    {:reply, :ok, state}
  end

  def handle_info(:dict_value, state) do
    value = ProcessTree.get(state.dict_key)
    send(state.test_pid, {state.name, :dict_value, value})
    {:noreply, state}
  end

  def handle_info(:exit, state) do
    IO.puts("genserver #{state.name} stopping")
    {:stop, :shutdown, state}
  end
end
