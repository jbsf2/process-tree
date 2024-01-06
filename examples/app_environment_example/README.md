# Application Environment Example

<!-- MDOC -->
<!-- INCLUDE -->

This example demonstrates how `ProcessTree` can be used in tests to provide custom values for 
environment variables, while preserving `async: true`.

The example is a Phoenix app with a single LiveView that serves the site's index page. The 
LiveView uses an environment variable called `cutoff_date` to customize the appearance of the 
index page. When a viewer hits the page before the cutoff date, they see this message:

<blockquote>
<pre>
    Welcome! You've made the cutoff date :-)
</pre>
</blockquote>

When a viewer hits the page after the cutoff date, they see this message:

<blockquote>
<pre>
    Sorry! You've missed the cutoff date :-(
</pre>
</blockquote>

For "real-life" usage when `MIX_ENV=dev` or `MIX_ENV=prod`, the `cutoff_date` is set in `runtime.exs` as a hardcoded 
Application environment variable:

``` elixir
config :app_environment_example, cutoff_date: ~D[2024-01-01]
```

In our tests of the LiveView, we override the value on a test-specific basis by writing the desired
custom value to the process dictionary of the ExUnit test pid:

``` elixir
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
```

Since this custom value is scoped to individual ExUnit tests, rather than to the global Application environment, the tests are safe for `async: true`.

The code for the LiveView is below. In the `cutoff_date()` function, the LiveView uses `ProcessTree` to look for a customized value. If no custom value is found (as when running in `dev` or `prod`), then the LiveView uses the `cutoff_date` retrieved from the Application environment, as configured in `runtime.exs` 

``` elixir
defmodule AppEnvironmentExampleWeb.WelcomeLive.Show do
  @moduledoc false
  use AppEnvironmentExampleWeb, :live_view

  @impl true
  def render(assigns) do
    message = case Date.before?(Date.utc_today(), cutoff_date()) do
      true ->
        "Welcome! You've made the cutoff date :-)"

      false ->
        "Sorry! You've missed the cutoff date :-("
    end

    assigns = assign(assigns, :message, message)

    ~H"""
    <h1 style='padding: 3em'><%= @message %></h1>
    """
  end

  defp cutoff_date() do
    # read the default cutoff_date from the Application environment
    app_env_cutoff_date = Application.get_env(:app_environment_example, :cutoff_date)

    # ProcessTree will look for a customized cutoff_date value in the process dictionaries
    # of this process and its ancestors.
    #
    # When running our tests, ProcessTree will find and return the customized value that
    # we have inserted into the process dictionary of the ExUnit test pid, which is an
    # ancestor of this LiveView process.
    #
    # When running in production, ProcessTree will not find a value in any ancestor
    # dictionaries, and it will return the default value after caching it in the process
    # dictionary of the current process.
    ProcessTree.get(:cutoff_date, default: app_env_cutoff_date)
  end
end
```

During tests, the LiveView "sees" the custom value because `ProcessTree` looks up the process ancestry hierarchy to 
find the value. The LiveView process is spawned by the ExUnit test pid (indirectly, via the ExUnit test supervisor), meaning that the test pid is an ancestor of the LiveView. `ProcessTree` eventually finds the custom value in the process dictionary of the test pid.

In production, `ProcessTree` returns the default value obtained from the Application environment.


