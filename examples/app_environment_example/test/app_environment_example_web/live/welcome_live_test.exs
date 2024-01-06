defmodule AppEnvironmentExampleWeb.WelcomeLiveTest do
  use AppEnvironmentExampleWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Show" do

    setup context do
      context
      |> Map.put(:today, Date.utc_today())
    end

    test "when the cutoff date has not passed, shows a 'welcome' message", %{conn: conn, today: today} do
      IO.inspect(self(), label: "test pid")
      IO.inspect(ExUnit.fetch_test_supervisor, label: "supervisor")
      tomorrow = Date.add(today, 1)
      Process.put(:cutoff_date, tomorrow)

      {:ok, _show_live, html} = live(conn, ~p"/welcome")

      assert html =~ "Welcome!"
    end

    test "when cutoff date has passed, shows a 'sorry' message", %{conn: conn, today: today} do
      IO.inspect(self(), label: "test pid")
      yesterday = Date.add(today, -1)
      Process.put(:cutoff_date, yesterday)

      {:ok, _show_live, html} = live(conn, ~p"/welcome")

      assert html =~ "Sorry!"
    end
  end
end
