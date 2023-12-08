defmodule ProcessTree do
  @moduledoc """
  For lack of a clearly better alternative, `ProcessTree` is just a home for its
  two public functions: `get_dictionary_value/1` and `get_dictionary_value/2`.

  Developers using these functions should feel free to copy/move them wherever they like!
  """

  @doc """
  Starting with the calling process, recursively looks for a value for `key` in
  the process dictionaries of the calling process and its ancestors.

  If a particular ancestor process has died, it looks up to the next ancestor.

  If a non-nil value is found in the tree, the value is cached in the dictionary of
  the calling process.

  Returns the first non-nil value found in the tree. If no value is found, returns `nil`.
  """
  @spec get_dictionary_value(atom()) :: any()
  def get_dictionary_value(key) do
    case Process.get(key) do
      nil ->
        ancestor_value(key, Process.get(:"$ancestors"))

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
  @spec get_dictionary_value(atom(), default: any()) :: any()
  def get_dictionary_value(key, default: default_value) do
    case get_dictionary_value(key) do
      nil ->
        Process.put(key, default_value)
        default_value

      value ->
        value
    end
  end

  @spec ancestor_value(atom(), [pid()]) :: any()
  defp ancestor_value(_key, nil), do: nil
  defp ancestor_value(_key, []), do: nil

  defp ancestor_value(key, ancestors) do
    [current_ancestor | older_ancestors] = ancestors

    current_ancestor = get_pid(current_ancestor)

    info = Process.info(current_ancestor)

    cond do
      process_died?(info) ->
        ancestor_value(key, older_ancestors)

      (value = get_from_dictionary(info, key)) != nil ->
        Process.put(key, value)
        value

      true ->
        ancestor_value(key, older_ancestors)
    end
  end

  @spec process_died?(keyword()) :: boolean()
  defp process_died?(process_info), do: process_info == nil

  @spec get_from_dictionary(keyword(), atom()) :: any()
  defp get_from_dictionary(process_info, key) do
    dictionary = Keyword.get(process_info, :dictionary)
    Keyword.get(dictionary, key)
  end

  @spec get_pid(pid() | atom()) :: pid()
  defp get_pid(pid_or_registered_name) do
    case is_pid(pid_or_registered_name) do
      true ->
        pid_or_registered_name

      false ->
        Process.whereis(pid_or_registered_name)
    end
  end
end
