defmodule ProcessTree do
  @external_resource "README.md"

  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC -->")
             |> Enum.filter(&(&1 =~ ~r{<!\-\-\ INCLUDE\ \-\->}))
             |> Enum.join("\n")
             # compensate for anchor id differences between ExDoc and GitHub
             |> (&Regex.replace(~r{\(\#\K(?=[a-z][a-z0-9-]+\))}, &1, "module-")).()

  alias ProcessTree.OtpRelease

  @typep id :: pid() | atom()

  if !OtpRelease.process_info_tracks_parent?() do
    # suppress warnings seen in OTP 24 and earlier
    @dialyzer {:no_match, {:known_ancestors, 3}}
    @dialyzer {:no_match, {:ancestor_value, 3}}
    @dialyzer {:no_unused, {:older_dictionary_ancestors, 2}}
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

  Default values might typically be read from the Application environment. For example:

  ```
  default_value = Application.get_env(:my_app, :some_key)
  value = ProcessTree.get(:some_key, default: default_value)
  ```
  """
  @spec get(term(), keyword()) :: term()
  def get(key, opts \\ []) do
    case actually_get(key, opts) do
      nil ->
        cache_result? = !(opts[:cache] == false)
        if cache_result? && (opts[:default] != nil), do: Process.put(key, opts[:default])
        opts[:default]

      value ->
        value
    end
  end

  @doc """
  Returns a list of the known ancestors of `pid`, from "newest" to "oldest".

  The set of ancestors that is "known" depends on factors including:

  * The OTP major version the code is running under. (OTP 25 [introduced](https://github.com/erlang/otp/pull/5768)
    new functionality for tracking ancestors.)
  * Whether the process and its ancestors are running in a supervision tree
  * Whether ancestor processes are still alive
  * Whether the given process and its ancestors were started via raw `spawn` or
    were instead started as Tasks, Agents, GenServers or Supervisors

  `ProcessTree` takes these factors and more into account and produces the most complete
  list of ancestors that is possible.

  In the mainline case - running under a supervision tree, as recommended - `known_ancestors/1` will
  return a list that contains, at minimum, all of the ancestor Supervisors in the tree
  as well as the ancestor of the initial/topmost Supervisor.

  When running under OTP 25 and later, the list will also include all additional ancestors,
  up to and including the `:init` process (`PID<0.0.0>`), provided that the additional ancestor
  processes are still alive.

  List items will be pids in all but the most unusual of circumstances. For example, if a GenServer
  is spawned by parent/grandparent GenServers that have registered names, and the parent GenServer dies,
  then the parent & grandparent may be represented in the list of the child's known ancestors using
  the their registered names - atoms, rather than pids. Precise behavior depends on OTP major version.
  """
  @spec known_ancestors(pid()) :: [pid() | atom()]
  def known_ancestors(pid) do
    known_ancestors(pid, [], dictionary_ancestors(pid))
    |> Enum.reverse()
  end

  @doc """
  Returns the parent of `pid`, if the parent is known.

  Returns `:unknown` if the parent is unknown.

  Returns `:undefined` if `pid` represents the `:init` process (`PID<0.0.0>`).

  If `pid` is part of a supervision tree, the parent will be known regardless of any other factors.

  If the parent is known, the return value will be a pid in all but the most unusual of
  circumstances. See `known_ancestors/1` for dicussion.
  """
  @spec parent(pid()) :: pid() | atom()
  def parent(pid) do
    case Process.whereis(:init) do
      ^pid -> :undefined
      _ -> ancestor(pid, 1)
    end
  end

  defp actually_get(key, opts) do
    case Process.get(key) do
      nil ->
        ancestor_value(key, self(), dictionary_ancestors(self()), opts[:cache])

      value ->
        value
    end
  end

  defp ancestor(pid, index) do
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

  @spec process_info_parent(id()) :: pid() | nil
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

  @spec ancestor_value(term(), id(), [id()], boolean) :: term()
  defp ancestor_value(key, pid_or_name, dictionary_ancestors, cache?) do
    cond do
      (value = get_dictionary_value(pid_or_name, key)) != nil ->
        if cache?, do: Process.put(key, value)
        value

      (parent = process_info_parent(pid_or_name)) != nil ->
        older_dictionary_ancestors = older_dictionary_ancestors(parent, dictionary_ancestors)
        ancestor_value(key, parent, older_dictionary_ancestors, cache?)

      length(dictionary_ancestors) > 0 ->
        [parent | older_ancestors] = dictionary_ancestors
        ancestor_value(key, parent, older_ancestors, cache?)

      true ->
        nil
    end
  end

  @spec get_dictionary_value(id(), atom()) :: term()
  defp get_dictionary_value(nil, _key), do: nil

  defp get_dictionary_value(name, _key) when is_atom(name) do
    # we already know the process has died
    nil
  end

  defp get_dictionary_value(pid, key) do
    case Process.info(pid, :dictionary) do
      nil ->
        nil

      {:dictionary, dictionary} ->
        case List.keyfind(dictionary, key, 0) do
          {_key, value} ->
            value

          nil ->
            nil
        end
    end
  end

  defp dictionary_ancestors(pid) do
    (get_dictionary_value(pid, :"$ancestors") || [])
    |> Enum.map(&get_pid_if_available/1)
  end

  @spec get_pid_if_available(pid() | atom()) :: pid() | atom()
  defp get_pid_if_available(pid_or_registered_name) do
    case is_pid(pid_or_registered_name) do
      true ->
        pid_or_registered_name

      false ->
        Process.whereis(pid_or_registered_name) || pid_or_registered_name
    end
  end
end
