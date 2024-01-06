defmodule AppEnvironmentExampleWeb.PageController do
  @moduledoc false

  use AppEnvironmentExampleWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
