defmodule GenServerExample.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GenServerExampleWeb.Endpoint,
      {Phoenix.PubSub, name: GenServerExample.PubSub},
    ]

    opts = [strategy: :one_for_one, name: GenServerExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    GenServerExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
