# AppEnvironmentExample

<!-- MDOC -->
<!-- INCLUDE -->

This example demonstrates how `ProcessTree` can be used in tests to provide custom values for 
environment variables, while preserving `async: true`.

The example is a Phoenix app with a single LiveView that serves the site's index page. The 
LiveView uses an environment variable called `cutoff_date` to customize the appearance of the 
index page. When a viewer hits the page before the cutoff date, they see this message:


When a viewer hits the page after the cutoff date, they see this message:

For usage when `MIX_ENV=dev` or `MIX_ENV=prod`, the `cutoff_date` is set in `runtime.exs` as a hardcoded 
Application environment variable:



In our tests of the LiveView, we override the value on a test-specific basis by writing the desired
custom value to the process dictionary of the ExUnit test pid:

Since this custom value is scoped to the ExUnit test, rather than to the global Application environment, the test is safe for `async: true`.

Our LiveView uses `ProcessTree` to look for a customized value. If no custom value is found (as when running in `dev`
or `prod`), then the LiveView uses the `cutoff_date` configured in `runtime.exs`. 

During tests, the LiveView "sees" the custom value because `ProcessTree` looks up the process ancestry hierarchy to 
find the value. The LiveView process is spawned by the ExUnit test pid (indirectly, via the ExUnit test supervisor), meaning that the test pid is an ancestor of the LiveView. `ProcessTree` eventually finds the custom value in the process dictionary of the test pid.






To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

