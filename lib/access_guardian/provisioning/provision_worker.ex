defmodule AccessGuardian.Provisioning.ProvisionWorker do
  use Oban.Worker, queue: :provisioning, max_attempts: 8
  require Logger

  alias AccessGuardian.Provisioning.Adapters

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => request_id}}) do
    {:ok, request} = AccessGuardian.Access.get_request(request_id)
    {:ok, app} = AccessGuardian.Catalog.get_application(request.application_id)
    {:ok, user} = AccessGuardian.Catalog.get_user(request.affected_user_id)

    adapter = select_adapter(app)
    Logger.info("[ProvisionWorker] Using #{adapter_label(adapter)} for #{app.name}")

    case adapter.provision(app, user, request.entitlements) do
      {:ok, :pending_manual} ->
        AccessGuardian.Access.mark_pending_manual(request)
        :ok

      {:ok, result} ->
        case AccessGuardian.Access.complete_provisioning(request, %{
               adapter_type: adapter_label(adapter),
               external_account_id: result.external_account_id
             }) do
          {:ok, _} ->
            :ok

          {:error, err} ->
            Logger.error("[ProvisionWorker] complete_provisioning failed: #{inspect(err)}")
        end

        :ok

      {:error, :permanent, reason} ->
        AccessGuardian.Access.fail_provisioning(request, %{
          adapter_type: adapter_label(adapter),
          error_reason: reason
        })

        :ok

      {:error, :transient, reason} ->
        {:error, reason}
    end
  end

  def select_adapter(app) do
    case app.integration_type do
      :api ->
        if has_config?(app, "github_org") and env_set?("GITHUB_TOKEN"),
          do: Adapters.GithubAdapter,
          else: Adapters.ApiAdapter

      :agentic ->
        if has_config?(app, "notion_workspace_url") and env_set?("NOTION_EMAIL"),
          do: Adapters.NotionAdapter,
          else: Adapters.AgenticAdapter

      :scim ->
        Adapters.ScimAdapter

      :manual ->
        Adapters.ManualAdapter
    end
  end

  defp has_config?(app, key) do
    is_map(app.config) and Map.has_key?(app.config, key) and
      app.config[key] not in [nil, ""]
  end

  defp env_set?(var), do: System.get_env(var) not in [nil, ""]

  defp adapter_label(Adapters.GithubAdapter), do: "github_api"
  defp adapter_label(Adapters.NotionAdapter), do: "notion_playwright"
  defp adapter_label(Adapters.ApiAdapter), do: "api_simulated"
  defp adapter_label(Adapters.AgenticAdapter), do: "agentic_simulated"
  defp adapter_label(Adapters.ScimAdapter), do: "scim_simulated"
  defp adapter_label(Adapters.ManualAdapter), do: "manual"
  defp adapter_label(module), do: to_string(module)
end
