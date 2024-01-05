defmodule ProcessTree do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.filter(&(&1 =~ ~R{<!\-\-\ INCLUDE\ \-\->}))
             |> Enum.join("\n")
             # compensate for anchor id differences between ExDoc and GitHub
             |> (&Regex.replace(~R{\(\#\K(?=[a-z][a-z0-9-]+\))}, &1, "module-")).()

  alias ProcessTree.OtpRelease

  @typep id :: pid() | atom()

  @doc """
  Starting with the calling process, recursively looks for a value for `key` in
  the process dictionaries of the calling process and its known ancestors.

  If a particular ancestor process has died, it looks up to the next ancestor, if possible.

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
  process dictionaries of the calling process and its known ancestors.

  If a particular ancestor process has died, it looks up to the next ancestor, if possible.

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

  @spec known_ancestors(pid()) :: [pid() | atom()]
  def known_ancestors(pid) do
    known_ancestors(pid, [], dictionary_ancestors(pid))
    |> Enum.reverse()
  end

  @spec parent(pid()) :: pid() | atom()
  def parent(pid), do: ancestor(pid, 1)

  @doc false
  @spec ancestor(pid(), non_neg_integer()) :: id()
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

  @spec known_ancestors(id(), [id()], [id()]) :: [id()]
  defp known_ancestors(pid_or_name, collected_ancestors, dictionary_ancestors) do
    cond do
      pid_or_name == nil ->
        collected_ancestors

      pid_or_name == init_pid() ->
        collected_ancestors

      (parent = process_info_parent(pid_or_name)) != nil ->
        older_dictionary_ancestors = older_dictionary_ancestors(parent, dictionary_ancestors)
        known_ancestors(parent, [parent | collected_ancestors], older_dictionary_ancestors)

      length(dictionary_ancestors) > 0 ->
        [parent | older_ancestors] = dictionary_ancestors
        known_ancestors(parent, [parent | collected_ancestors], older_ancestors)

      true ->
        collected_ancestors
    end
  end

  @spec init_pid() :: pid()
  defp init_pid() do
    Process.whereis(:init)
  end

  @spec older_dictionary_ancestors(pid, [id()]) :: [id()]
  defp older_dictionary_ancestors(parent, []) do
    dictionary_ancestors(parent)
  end

  defp older_dictionary_ancestors(_parent, child_dictionary_ancestors) do
    [_parent | older_ancestors] = child_dictionary_ancestors
    older_ancestors
  end

  @spec process_info_parent(id()) :: pid()
  defp process_info_parent(name) when is_atom(name) do
    nil
  end

  if OtpRelease.process_info_tracks_parent?() do
    defp process_info_parent(pid) do
      case Process.info(pid, :parent) do
        {:parent, :undefined} ->
          nil

        {:parent, parent} ->
          parent

        nil ->
          nil
      end
    end
  else
    defp process_info_parent(_pid), do: nil
  end


  @spec ancestor_value(any(), id(), [id()]) :: any()
  defp ancestor_value(key, pid_or_name, dictionary_ancestors) do
    cond do
      (value = get_dictionary_value(pid_or_name, key)) != nil ->
        Process.put(key, value)
        value

      (parent = process_info_parent(pid_or_name)) != nil ->
        older_dictionary_ancestors = older_dictionary_ancestors(parent, dictionary_ancestors)
        ancestor_value(key, parent, older_dictionary_ancestors)

      length(dictionary_ancestors) > 0 ->
        [parent | older_ancestors] = dictionary_ancestors
        ancestor_value(key, parent, older_ancestors)

      true ->
        nil
    end
  end

  @spec get_dictionary_value(id(), atom()) :: any()
  defp get_dictionary_value(nil, _key), do: nil

  defp get_dictionary_value(name, _key) when is_atom(name) do
    # we already know the process has died
    nil
  end

  if OtpRelease.optimized_dictionary_access?() do
    defp get_dictionary_value(pid, key) do
      Process.info(pid, {:dictionary, key})
    end
  else
    defp get_dictionary_value(pid, key) do
      case Process.info(pid, :dictionary) do
        nil ->
          nil

        {:dictionary, dictionary} ->
          Keyword.get(dictionary, key)
      end
    end
  end

  defp dictionary_ancestors(pid) do
    (get_dictionary_value(pid, :"$ancestors") || [])
    |> Enum.map(&get_pid_if_available/1)
  end

  @spec get_pid_if_available(pid() | atom()) :: pid()
  defp get_pid_if_available(pid_or_registered_name) do
    case is_pid(pid_or_registered_name) do
      true ->
        pid_or_registered_name

      false ->
        Process.whereis(pid_or_registered_name) || pid_or_registered_name
    end
  end
end
