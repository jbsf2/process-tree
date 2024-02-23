defmodule VersionSwitcher do

  def run() do
    [package, version] = hd(System.argv()) |> String.split("=")
    switch(package, version)
  end

  def switch("otp", otp_version) do
    {_, 0} = System.cmd("asdf", ["local", "erlang", erlang_build(otp_version)])
    {_, 0} = System.cmd("asdf", ["local", "elixir", elixir_build(otp_version, current_elixir_version())])
  end

  def switch("elixir", elixir_version) do
    {_, 0} = System.cmd("asdf", ["local", "elixir", elixir_build(current_otp_version(), elixir_version)])
  end

  def current_elixir_version() do
    System.build_info()
    |> Map.get(:version)
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.join(".")
  end

  def current_otp_version() do
    System.build_info()
    |> Map.get(:otp_release)
  end

  def elixir_build(otp_version, elixir_version) do
    %{
      {"24", "1.14"} => "1.14.5-otp-24",
      {"25", "1.14"} => "1.14.5-otp-25",
      {"26", "1.14"} => "1.14.5-otp-26",

      {"24", "1.15"} => "1.15.7-otp-24",
      {"25", "1.15"} => "1.15.7-otp-25",
      {"26", "1.15"} => "1.15.7-otp-26",

      {"24", "1.16"} => "1.16.1-otp-24",
      {"25", "1.16"} => "1.16.1-otp-25",
      {"26", "1.16"} => "1.16.1-otp-26",
    }
    |> Map.get({otp_version, elixir_version})
  end

  def erlang_build(otp_version) do
    %{
      "24" => "24.3.4.14",
      "25" => "25.3.2.7",
      "26" => "26.2.2"
    }
    |> Map.get(otp_version)
  end
end

VersionSwitcher.run()
