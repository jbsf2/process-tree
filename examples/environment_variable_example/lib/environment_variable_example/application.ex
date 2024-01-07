defmodule EnvironmentVariableExample.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EnvironmentVariableExampleWeb.Endpoint,
      {Phoenix.PubSub, name: EnvironmentVariableExample.PubSub},
    ]

    opts = [strategy: :one_for_one, name: EnvironmentVariableExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    EnvironmentVariableExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
