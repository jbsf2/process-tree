defmodule ElixirRelease do
  @moduledoc false

  def task_spawned_by_proc_lib?() do
    case major_version() == 1 do
      true ->
        minor_version() < 15

      false ->
        false
    end
  end

  defp major_version() do
    System.version()
    |> String.split(".")
    |> hd()
    |> String.to_integer()
  end

  defp minor_version() do
    System.version()
    |> String.split(".")
    |> Enum.at(1)
    |> String.to_integer()
  end
end
