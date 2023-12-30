defmodule TestGenserver do
  use GenServer

  defstruct [
    :test_pid,
    :name
  ]

  def init({test_pid, name}) do
    state = %__MODULE__{
      test_pid: test_pid,
      name: name
    }

    {:ok, state}
  end

  def handle_call({:execute, function}, _from, state) do
    if function != nil do
      {:ok, _pid} = function.()
    end

    {:reply, :ok, state}
  end

  def handle_info({:dict_value, dict_key}, state) do
    value = ProcessTree.get(dict_key)
    send(state.test_pid, {state.name, :dict_value, value})
    {:noreply, state}
  end

  def handle_info(:exit, state) do
    IO.puts("genserver #{state.name} stopping")
    {:stop, :shutdown, state}
  end
end
