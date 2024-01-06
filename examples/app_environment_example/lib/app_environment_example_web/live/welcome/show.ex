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
    app_env_cutoff_date = Application.get_env(:application_environment, :cutoff_date)
    ProcessTree.get(:cutoff_date, default: app_env_cutoff_date)
  end
end
