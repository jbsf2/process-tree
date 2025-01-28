defmodule ClusterHelper do
  def apply_and_reply(test_pid, {m,f,a}) do
    apply(m, f, a)
    send(test_pid, :done)
  end
end
