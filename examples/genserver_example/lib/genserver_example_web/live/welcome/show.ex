defmodule GenServerExampleWeb.WelcomeLive.Show do
  @moduledoc false
  use GenServerExampleWeb, :live_view

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
    app_env_cutoff_date = Application.get_env(:genserver_example, :cutoff_date)

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
