defmodule ApplicationEnvironment.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ApplicationEnvironmentWeb.Telemetry,
      ApplicationEnvironment.Repo,
      {DNSCluster, query: Application.get_env(:application_environment, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ApplicationEnvironment.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ApplicationEnvironment.Finch},
      # Start a worker by calling: ApplicationEnvironment.Worker.start_link(arg)
      # {ApplicationEnvironment.Worker, arg},
      # Start to serve requests, typically the last entry
      ApplicationEnvironmentWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ApplicationEnvironment.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ApplicationEnvironmentWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
