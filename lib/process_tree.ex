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

  def ancestor(pid, 0), do: pid

  def ancestor(pid, ancestor_index) do
    proclib_ancestors =
      case Process.info(pid) do
        nil ->
          []

        info ->
          get_from_dictionary(info, :"$ancestors") || []
      end

    ancestor(pid, ancestor_index, proclib_ancestors)
  end

  @spec ancestor(pid(), non_neg_integer(), [pid()]) :: pid()
  defp ancestor(pid, 0, _proclib_ancestors), do: pid

  defp ancestor(pid, ancestor_index, proclib_ancestors) do
    proclib_parent =
      case length(proclib_ancestors) > 0 do
        true ->
          hd(proclib_ancestors)

        false ->
          nil
      end

    older_proclib_ancestors =
      case length(proclib_ancestors) > 1 do
        true ->
          tl(proclib_ancestors)

        false ->
          []
      end

    case process_info_parent(pid) do
      nil ->
        case proclib_parent do
          nil ->
            :unknown

          parent ->
            ancestor(parent, ancestor_index - 1, older_proclib_ancestors)
        end

      {:parent, parent} ->
        ancestor(parent, ancestor_index - 1, older_proclib_ancestors)
    end
  end

  def parent(pid), do: ancestor(pid, 1)
  def grandparent(pid), do: ancestor(pid, 2)

  def init_pid() do
    Process.whereis(:init)
  end

  defp process_info_parent(pid) do
    with true <- process_info_tracks_parent(),
         true <- Process.alive?(pid) do
      case Process.info(pid, :parent) do
        {:parent, :undefined} ->
          nil

        {:parent, parent} ->
          {:parent, parent}
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
