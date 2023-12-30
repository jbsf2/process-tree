defmodule ProcessTree do
  @moduledoc """
  For lack of a clearly better alternative, `ProcessTree` is just a home for its
  two public functions: `get/1` and `get/2`.

  Developers using these functions should feel free to copy/move them wherever they like!
  """

  defmodule UnknownAncestorError do
    @moduledoc false
    defexception message: "Unknown ancestor process"
  end

  @doc """
  Starting with the calling process, recursively looks for a value for `key` in
  the process dictionaries of the calling process and its ancestors.

  If a particular ancestor process has died, it looks up to the next ancestor.

  If a non-nil value is found in the tree, the value is cached in the dictionary of
  the calling process.

  Returns the first non-nil value found in the tree. If no value is found, returns `nil`.
  """
  @spec get(atom()) :: any()
  def get(key) do
    case Process.get(key) do
      nil ->
        ancestor_value(key, self(), dictionary_ancestors(self()))

      value ->
        value
    end
  end

  @doc """
  Starting with the calling process, recursively looks for a value for `key` in the
  process dictionaries of the calling process and its ancestors.

  If a particular ancestor process has died, it looks up to the next ancestor.

  If a non-nil value is found in the tree, the value is cached in the dictionary of
  the calling process.

  Returns the first non-nil value found in the tree.

  If no value is found, the provided default value is cached in the dictionary of the
  calling process and then returned.
  """
  @spec get(atom(), default: any()) :: any()
  def get(key, default: default_value) do
    case get(key) do
      nil ->
        Process.put(key, default_value)
        default_value

      value ->
        value
    end
  end

  @spec known_ancestors(pid()) :: [pid()]
  def known_ancestors(pid) do
    known_ancestors(pid, [], dictionary_ancestors(pid))
    |> Enum.reverse()
  end

  @spec parent(pid()) :: pid()
  def parent(pid), do: ancestor(pid, 1)

  @doc false
  def ancestor(pid, 0) do
    pid
  end

  @doc false
  def ancestor(pid, index) do
    ancestors = known_ancestors(pid)

    case length(ancestors) >= index do
      true ->
        Enum.at(ancestors, index - 1)

      false ->
        :unknown
    end
  end

  defp known_ancestors(pid, collected_ancestors, dictionary_ancestors) do
    cond do
      pid == nil ->
        collected_ancestors

      pid == init_pid() ->
        collected_ancestors

      (parent = process_info_parent(pid)) != nil ->
        older_dictionary_ancestors = older_dictionary_ancestors(parent, dictionary_ancestors)
        known_ancestors(parent, [parent | collected_ancestors], older_dictionary_ancestors)

      length(dictionary_ancestors) > 0 ->
        [parent | older_ancestors] = dictionary_ancestors
        known_ancestors(parent, [parent | collected_ancestors], older_ancestors)

      true ->
        collected_ancestors
    end
  end

  defp init_pid() do
    Process.whereis(:init)
  end

  defp older_dictionary_ancestors(parent, []) do
    dictionary_ancestors(parent)
  end

  defp older_dictionary_ancestors(_parent, child_dictionary_ancestors) do
    [_parent | older_ancestors] = child_dictionary_ancestors
    older_ancestors
  end

  defp process_info_parent(pid) do
    with true <- process_info_tracks_parent() do
      case Process.info(pid, :parent) do
        {:parent, :undefined} ->
          nil

        {:parent, parent} ->
          parent

        nil ->
          nil
      end
    else
      _ ->
        nil
    end
  end

  defp process_info_tracks_parent() do
    otp_release() >= 25
  end

  @doc false
  def otp_release() do
    String.to_integer(System.otp_release())
  end

  @spec ancestor_value(any(), pid(), [pid()]) :: any()
  defp ancestor_value(key, pid, dictionary_ancestors) do
    cond do
      (value = get_dictionary_value(pid, key)) != nil ->
        Process.put(key, value)
        value

      (parent = process_info_parent(pid)) != nil ->
        older_dictionary_ancestors = older_dictionary_ancestors(parent, dictionary_ancestors)
        ancestor_value(key, parent, older_dictionary_ancestors)

      length(dictionary_ancestors) > 0 ->
        [parent | older_ancestors] = dictionary_ancestors
        ancestor_value(key, parent, older_ancestors)

      true ->
        nil
    end
  end

  @spec get_dictionary_value(pid(), atom()) :: any()
  defp get_dictionary_value(nil, _key), do: nil

  defp get_dictionary_value(pid, key) do
    case Process.info(pid, :dictionary) do
      nil ->
        nil

      {:dictionary, dictionary} ->
        Keyword.get(dictionary, key)
    end
  end

  defp dictionary_ancestors(pid) do
    (get_dictionary_value(pid, :"$ancestors") || [])
    |> Enum.map(&get_pid/1)
  end

  @spec get_pid(pid() | atom()) :: pid()
  defp get_pid(pid_or_registered_name) do
    # When a process has a registered name, proc_lib uses the
    # name rather than the pid when inserting a process into
    # $ancestors.
    case is_pid(pid_or_registered_name) do
      true ->
        pid_or_registered_name

      false ->
        # will return nil if the process has died
        Process.whereis(pid_or_registered_name)
    end
  end
end
