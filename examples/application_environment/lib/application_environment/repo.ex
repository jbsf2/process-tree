defmodule ApplicationEnvironment.Repo do
  use Ecto.Repo,
    otp_app: :application_environment,
    adapter: Ecto.Adapters.Postgres
end
