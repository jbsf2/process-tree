defmodule TestGenserver do
  use GenServer

  defstruct [
    :test_pid,
    :name
  ]

  def start_link([test_pid, name, next_function]) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {test_pid, name}, name: name)
    :ok = GenServer.call(pid, {:execute, next_function})
    send(test_pid, {name, :ready, pid})
    {:ok, pid}
  end

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
    {:stop, :shutdown, state}
  end
end
