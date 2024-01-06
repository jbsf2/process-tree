defmodule AppEnvironmentExample.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AppEnvironmentExampleWeb.Endpoint,
      {Phoenix.PubSub, name: AppEnvironmentExample.PubSub},
    ]

    opts = [strategy: :one_for_one, name: AppEnvironmentExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AppEnvironmentExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
