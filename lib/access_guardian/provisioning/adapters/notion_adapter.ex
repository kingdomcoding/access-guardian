defmodule AccessGuardian.Provisioning.Adapters.NotionAdapter do
  @behaviour AccessGuardian.Provisioning.Adapter
  require Logger

  @impl true
  def provision(app, user, _entitlements) do
    email = to_string(user.email)
    workspace_url = app.config["notion_workspace_url"] || System.get_env("NOTION_WORKSPACE_URL")

    Logger.info("[NotionAdapter] Provisioning #{email} to workspace")
    run_playwright("provision", email, workspace_url)
  end

  @impl true
  def deprovision(app, user) do
    email = to_string(user.email)
    workspace_url = app.config["notion_workspace_url"] || System.get_env("NOTION_WORKSPACE_URL")

    Logger.info("[NotionAdapter] Deprovisioning #{email}")

    case run_playwright("deprovision", email, workspace_url) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp run_playwright(action, email, workspace_url) do
    script_path = Path.join(:code.priv_dir(:access_guardian), "playwright/notion.ts")

    env = [
      {"NOTION_EMAIL", System.get_env("NOTION_EMAIL") || ""},
      {"NOTION_PASSWORD", System.get_env("NOTION_PASSWORD") || ""},
      {"NOTION_WORKSPACE_URL", workspace_url || ""}
    ]

    Logger.info("[NotionAdapter] Running Playwright script: #{action} #{email}")

    case System.cmd("npx", ["tsx", script_path, action, email],
           env: env,
           stderr_to_stdout: true,
           cd: Path.join(:code.priv_dir(:access_guardian), "playwright")
         ) do
      {output, 0} ->
        case Jason.decode(String.trim(output)) do
          {:ok, result} ->
            log_steps(result["steps"])
            {:ok, %{external_account_id: result["external_account_id"]}}

          {:error, _} ->
            {:error, :permanent, "Failed to parse Playwright output"}
        end

      {output, _exit_code} ->
        case Jason.decode(String.trim(output)) do
          {:ok, result} ->
            log_steps(result["steps"])
            error_type = if result["error_type"] == "transient", do: :transient, else: :permanent
            {:error, error_type, result["error"] || "Playwright script failed"}

          {:error, _} ->
            {:error, :permanent, "Playwright failed: #{String.slice(output, 0, 200)}"}
        end
    end
  rescue
    e ->
      {:error, :permanent, "Playwright error: #{Exception.message(e)}"}
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
