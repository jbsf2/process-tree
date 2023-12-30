defmodule TestSupervisor do
  use Supervisor

  def start_link([test_pid, name, child_spec_function]) do
    {:ok, pid} = Supervisor.start_link(__MODULE__, nil, name: name)
    child_spec = child_spec_function.()
    {:ok, _child_pid} = Supervisor.start_child(pid, child_spec)
    send(test_pid, {name, :ready, pid})
    {:ok, pid}
  end

  def init(_arg) do
    Supervisor.init([], strategy: :one_for_one)
  end
end
