defmodule ProcessTree do
  @moduledoc """
  For lack of a clearly better alternative, `ProcessTree` is just a home for its
  two public functions: `get_dictionary_value/1` and `get_dictionary_value/2`.

  Developers using these functions should feel free to copy/move them wherever they like!
  """

  @doc """
  Starting with the calling process, recursively looks for a value for `key` in
  the process dictionaries of the calling process and its ancestors.

  Returns the first non-nil value found in the tree. If no value is found, returns `nil`.
  """
  @spec get_dictionary_value(atom()) :: any()
  def get_dictionary_value(key), do: lookup_value(key, self())

  @doc """
  Starting with the calling process, recursively looks for a value for `key` in the
  process dictionaries of the calling process and its ancestors.

  Returns the first non-nil value found in the tree.

  If no value is found, the provided default value is cached in the dictionary of the
  calling process and then returned.
  """
  @spec get_dictionary_value(atom(), default: any()) :: any()
  def get_dictionary_value(key, default: default_value) do
    case lookup_value(key, self()) do
      nil ->
        Process.put(key, default_value)
        default_value

      value ->
        value
    end
  end

  @spec lookup_value(atom(), pid()) :: any()
  defp lookup_value(_key, nil), do: nil

  defp lookup_value(key, pid) do
    info = Process.info(pid)

    cond do
      process_died?(info) ->
        nil

      (value = get_from_dictionary(info, key)) != nil ->
        value

      true ->
        lookup_value(key, ancestor_pid(info))
    end
  end

  @spec process_died?(keyword()) :: boolean()
  defp process_died?(process_info), do: process_info == nil

  @spec get_from_dictionary(keyword(), atom()) :: any()
  defp get_from_dictionary(process_info, key) do
    dictionary = Keyword.get(process_info, :dictionary)
    Keyword.get(dictionary, key)
  end

  @spec ancestor_pid(keyword()) :: pid() | port() | nil
  defp ancestor_pid(process_info) do
    ancestors = get_from_dictionary(process_info, :"$ancestors") || []
    first_ancestor = ancestors |> List.first()
    cond do
      first_ancestor == nil ->
        nil

      is_atom(first_ancestor) ->
        Process.whereis(first_ancestor)

      true ->
        first_ancestor
    end
  end
end
