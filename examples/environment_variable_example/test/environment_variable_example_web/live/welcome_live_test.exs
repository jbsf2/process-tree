defmodule EnvironmentVariableExampleWeb.WelcomeLiveTest do
  use EnvironmentVariableExampleWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "Show" do

    test "when the cutoff date has not passed, shows a 'welcome' message", %{conn: conn} do
      tomorrow = Date.add(Date.utc_today(), 1)

      # set the cutoff date to tomorrow by writing the value
      # to the process dictionary of the ExUnit test pid
      Process.put(:cutoff_date, tomorrow)

      {:ok, _show_live, html} = live(conn, ~p"/welcome")

      assert html =~ "Welcome!"
    end

    test "when cutoff date has passed, shows a 'sorry' message", %{conn: conn} do
      yesterday = Date.add(Date.utc_today(), -1)

      # set the cutoff date to yesterday by writing the value
      # to the process dictionary of the ExUnit test pid
      Process.put(:cutoff_date, yesterday)

      {:ok, _show_live, html} = live(conn, ~p"/welcome")

      assert html =~ "Sorry!"
    end
  end
end
