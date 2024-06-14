defmodule ScriptBuilder do

  def elixir_builds() do
    [
      {erlang_build("24"), "1.14.5-otp-24"},
      {erlang_build("25"), "1.14.5-otp-25"},
      {erlang_build("26"), "1.14.5-otp-26"},

      {erlang_build("24"), "1.15.8-otp-24"},
      {erlang_build("25"), "1.15.8-otp-25"},
      {erlang_build("26"), "1.15.8-otp-26"},

      {erlang_build("24"), "1.16.3-otp-24"},
      {erlang_build("25"), "1.16.3-otp-25"},
      {erlang_build("26"), "1.16.3-otp-26"},

      {erlang_build("25"), "1.17.0-otp-25"},
      {erlang_build("26"), "1.17.0-otp-26"},
      {erlang_build("27"), "1.17.0-otp-27"},
    ]
  end

  def erlang_build(otp_version) do
    erlang_builds()
    |> Map.get(otp_version)
  end

  def erlang_builds() do
    %{
      "24" => "24.3.4.14",
      "25" => "25.3.2.7",
      "26" => "26.0",
      "27" => "27.0"
    }
  end

  def asdf_commands() do
    erlang_builds()
    |> Enum.each(fn {_version, build} -> IO.puts("asdf install erlang #{build}") end)

    elixir_builds()
    |> Enum.each(fn {_erlang_build, build} -> IO.puts("asdf install elixir #{build}") end)
  end

  def test_commands() do
    IO.puts("#!/bin/bash\n")
    IO.puts("set -euo pipefail\n")
    elixir_builds()
    |> Enum.each(fn {erlang_build, elixir_build} ->
      IO.puts("asdf local erlang #{erlang_build}")
      IO.puts("asdf local elixir #{elixir_build}")
      IO.puts("mix local.hex --force")
      IO.puts("mix test\n")
    end)
  end

  def dialyzer_commands() do
    IO.puts("#!/bin/bash\n")
    IO.puts("set -euxo pipefail\n")
    elixir_builds()
    |> Enum.each(fn {erlang_build, elixir_build} ->
      IO.puts("asdf local erlang #{erlang_build}")
      IO.puts("asdf local elixir #{elixir_build}")
      IO.puts("rm -rf _build")
      IO.puts("mix local.hex --force")
      IO.puts("mix dialyzer\n")
    end)
  end
end

ScriptBuilder.dialyzer_commands()
