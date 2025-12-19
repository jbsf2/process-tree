#!/usr/bin/env elixir

defmodule VersionMatrix do
  @moduledoc """
  Runs tests or dialyzer across multiple Erlang/Elixir version combinations.

  Usage:
    elixir bin/version_matrix.exs test      # Run tests across all versions
    elixir bin/version_matrix.exs dialyzer  # Run dialyzer across all versions
    elixir bin/version_matrix.exs install   # Install all required versions
  """

  @erlang_versions %{
    "25" => "25.3.2.21",
    "26" => "26.2.5.16",
    "27" => "27.3.4.6",
    "28" => "28.3"
  }

  @elixir_builds [
    {"25", "1.14.5-otp-25"},
    {"26", "1.14.5-otp-26"},

    {"25", "1.15.8-otp-25"},
    {"26", "1.15.8-otp-26"},

    {"25", "1.16.3-otp-25"},
    {"26", "1.16.3-otp-26"},

    {"25", "1.17.3-otp-25"},
    {"26", "1.17.3-otp-26"},
    {"27", "1.17.3-otp-27"},

    {"25", "1.18.4-otp-25"},
    {"26", "1.18.4-otp-26"},
    {"27", "1.18.4-otp-27"},
    {"28", "1.18.4-otp-28"},

    {"26", "1.19.4-otp-26"},
    {"27", "1.19.4-otp-27"},
    {"28", "1.19.4-otp-28"}
  ]

  def main(args) do
    case args do
      ["test"] -> run(:test)
      ["dialyzer"] -> run(:dialyzer)
      ["install"] -> install_all()
      _ -> usage()
    end
  end

  defp usage do
    IO.puts("""
    Usage:
      elixir bin/version_matrix.exs test      # Run tests across all versions
      elixir bin/version_matrix.exs dialyzer  # Run dialyzer across all versions
      elixir bin/version_matrix.exs install   # Install all required versions
    """)

    System.halt(1)
  end

  defp version_combinations do
    Enum.map(@elixir_builds, fn {otp_major, elixir_version} ->
      erlang_version = Map.fetch!(@erlang_versions, otp_major)
      {erlang_version, elixir_version}
    end)
  end

  defp run(command) do
    combinations = version_combinations()
    total = length(combinations)

    results =
      combinations
      |> Enum.with_index(1)
      |> Enum.map(fn {{erlang, elixir}, index} ->
        IO.puts("\n#{IO.ANSI.cyan()}[#{index}/#{total}] Running #{command} with Erlang #{erlang}, Elixir #{elixir}#{IO.ANSI.reset()}\n")

        result = run_with_versions(erlang, elixir, command)

        case result do
          :ok -> IO.puts("#{IO.ANSI.green()}✓ Passed#{IO.ANSI.reset()}")
          {:error, code} -> IO.puts("#{IO.ANSI.red()}✗ Failed (exit code: #{code})#{IO.ANSI.reset()}")
        end

        {erlang, elixir, result}
      end)

    print_summary(results, command)
  end

  defp run_with_versions(erlang_version, elixir_version, command) do
    script = build_script(erlang_version, elixir_version, command)

    {_, exit_code} = System.shell(script)

    case exit_code do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp build_script(erlang_version, elixir_version, :test) do
    """
    set -euo pipefail
    export ASDF_ERLANG_VERSION=#{erlang_version}
    export ASDF_ELIXIR_VERSION=#{elixir_version}
    mix local.hex --force --if-missing
    mix deps.get
    mix deps.compile --force
    mix test --warnings-as-errors=false
    """
  end

  defp build_script(erlang_version, elixir_version, :dialyzer) do
    """
    set -euo pipefail
    export ASDF_ERLANG_VERSION=#{erlang_version}
    export ASDF_ELIXIR_VERSION=#{elixir_version}
    mix local.hex --force --if-missing
    mix deps.get
    mix deps.compile --force
    mix dialyzer
    """
  end

  defp print_summary(results, command) do
    IO.puts("\n#{IO.ANSI.cyan()}═══════════════════════════════════════════════════════════════#{IO.ANSI.reset()}")
    IO.puts("#{IO.ANSI.cyan()}Summary: #{command}#{IO.ANSI.reset()}\n")

    {passed, failed} = Enum.split_with(results, fn {_, _, result} -> result == :ok end)

    if length(failed) > 0 do
      IO.puts("#{IO.ANSI.red()}Failed:#{IO.ANSI.reset()}")

      Enum.each(failed, fn {erlang, elixir, _} ->
        IO.puts("  - Erlang #{erlang}, Elixir #{elixir}")
      end)

      IO.puts("")
    end

    IO.puts("#{IO.ANSI.green()}Passed: #{length(passed)}#{IO.ANSI.reset()}")
    IO.puts("#{IO.ANSI.red()}Failed: #{length(failed)}#{IO.ANSI.reset()}")

    if length(failed) > 0 do
      System.halt(1)
    end
  end

  defp install_all do
    IO.puts("#{IO.ANSI.cyan()}Installing Erlang versions...#{IO.ANSI.reset()}")
    IO.puts("#{IO.ANSI.yellow()}(Note: Erlang compilation can take 20-30 minutes per version)#{IO.ANSI.reset()}\n")

    Enum.each(@erlang_versions, fn {_major, version} ->
      if version_installed?("erlang", version) do
        IO.puts("#{IO.ANSI.green()}✓ Erlang #{version} already installed#{IO.ANSI.reset()}")
      else
        IO.puts("Installing Erlang #{version}...")
        exit_code = install_with_progress("asdf install erlang #{version}")

        if exit_code == 0 do
          IO.puts("\n#{IO.ANSI.green()}✓ Erlang #{version} installed#{IO.ANSI.reset()}")
        else
          IO.puts("\n#{IO.ANSI.red()}✗ Erlang #{version} failed to install (exit code: #{exit_code})#{IO.ANSI.reset()}")
        end
      end
    end)

    IO.puts("\n#{IO.ANSI.cyan()}Installing Elixir versions...#{IO.ANSI.reset()}\n")

    Enum.each(@elixir_builds, fn {_otp, version} ->
      if version_installed?("elixir", version) do
        IO.puts("#{IO.ANSI.green()}✓ Elixir #{version} already installed#{IO.ANSI.reset()}")
      else
        IO.puts("Installing Elixir #{version}...")
        exit_code = install_with_progress("asdf install elixir #{version}")

        if exit_code == 0 do
          IO.puts("\n#{IO.ANSI.green()}✓ Elixir #{version} installed#{IO.ANSI.reset()}")
        else
          IO.puts("\n#{IO.ANSI.red()}✗ Elixir #{version} failed to install (exit code: #{exit_code})#{IO.ANSI.reset()}")
        end
      end
    end)

    IO.puts("\n#{IO.ANSI.green()}Done!#{IO.ANSI.reset()}")
  end

  defp install_with_progress(command) do
    start_time = System.monotonic_time(:second)

    # Spawn the actual install task
    task = Task.async(fn ->
      {_output, exit_code} = System.shell(command)
      exit_code
    end)

    # Spawn a process to print periodic status updates
    status_pid = spawn_link(fn -> print_status_loop(start_time) end)

    # Wait for the install to complete
    exit_code = Task.await(task, :infinity)

    # Stop the status printer
    Process.exit(status_pid, :normal)

    exit_code
  end

  defp print_status_loop(start_time) do
    Process.sleep(5_000)
    elapsed = System.monotonic_time(:second) - start_time
    minutes = div(elapsed, 60)
    seconds = rem(elapsed, 60)
    IO.puts("#{IO.ANSI.yellow()}... still building (#{minutes}m #{seconds}s elapsed)#{IO.ANSI.reset()}")
    print_status_loop(start_time)
  end

  defp version_installed?(plugin, version) do
    {output, 0} = System.cmd("asdf", ["list", plugin])

    output
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.member?(version)
  end
end

VersionMatrix.main(System.argv())
