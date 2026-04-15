defmodule AccessGuardian.Provisioning.Adapters.NotionAdapter do
  @behaviour AccessGuardian.Provisioning.Adapter
  require Logger

  defp service_url do
    System.get_env("PLAYWRIGHT_SERVICE_URL") || "http://playwright:3000"
  end

  @impl true
  def provision(app, user, _entitlements) do
    email = to_string(user.email)
    workspace_url = app.config["notion_workspace_url"] || System.get_env("NOTION_WORKSPACE_URL")

    Logger.info("[NotionAdapter] Provisioning #{email} via Playwright service")

    case Req.post("#{service_url()}/provision",
           json: %{email: email, workspace_url: workspace_url},
           receive_timeout: 30_000,
           connect_options: [timeout: 5_000]
         ) do
      {:ok, %{status: 200, body: %{"success" => true} = body}} ->
        log_steps(body["steps"])
        {:ok, %{external_account_id: body["external_account_id"]}}

      {:ok, %{status: 200, body: %{"success" => false} = body}} ->
        log_steps(body["steps"])
        error_type = if body["error_type"] == "transient", do: :transient, else: :permanent
        {:error, error_type, body["error"] || "Playwright automation failed"}

      {:ok, %{status: status, body: body}} ->
        {:error, :transient, "Playwright service returned #{status}: #{inspect(body)}"}

      {:error, %{reason: :econnrefused}} ->
        {:error, :transient, "Playwright service not available (connection refused)"}

      {:error, reason} ->
        {:error, :transient, "Playwright service error: #{inspect(reason)}"}
    end
  end

  @impl true
  def deprovision(app, user) do
    email = to_string(user.email)
    workspace_url = app.config["notion_workspace_url"] || System.get_env("NOTION_WORKSPACE_URL")

    Logger.info("[NotionAdapter] Deprovisioning #{email} via Playwright service")

    case Req.post("#{service_url()}/deprovision",
           json: %{email: email, workspace_url: workspace_url},
           receive_timeout: 30_000,
           connect_options: [timeout: 5_000]
         ) do
      {:ok, %{status: 200, body: %{"success" => true}}} -> :ok
      {:ok, %{status: 200, body: %{"success" => false} = body}} ->
        error_type = if body["error_type"] == "transient", do: :transient, else: :permanent
        {:error, error_type, body["error"] || "Deprovision failed"}
      {:error, %{reason: :econnrefused}} ->
        {:error, :transient, "Playwright service not available"}
      {:error, reason} ->
        {:error, :transient, "Playwright service error: #{inspect(reason)}"}
    end
  end

  defp log_steps(nil), do: :ok

  defp log_steps(steps) when is_list(steps) do
    total = length(steps)

    Enum.each(steps, fn step ->
      Logger.info(
        "[NotionAdapter] Step #{step["step"]}/#{total}: #{step["name"]} — #{step["status"]}"
      )
    end)
  end
end
