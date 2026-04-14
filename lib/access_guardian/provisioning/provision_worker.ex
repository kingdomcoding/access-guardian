defmodule AccessGuardian.Provisioning.ProvisionWorker do
  use Oban.Worker, queue: :provisioning, max_attempts: 8

  alias AccessGuardian.Provisioning.Adapters

  @adapter_map %{
    api: Adapters.ApiAdapter,
    agentic: Adapters.AgenticAdapter,
    scim: Adapters.ScimAdapter,
    manual: Adapters.ManualAdapter
  }

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => request_id}}) do
    {:ok, request} = AccessGuardian.Access.get_request(request_id)
    {:ok, app} = AccessGuardian.Catalog.get_application(request.application_id)
    {:ok, user} = AccessGuardian.Catalog.get_user(request.affected_user_id)

    adapter = Map.fetch!(@adapter_map, app.integration_type)

    case adapter.provision(app, user, request.entitlements) do
      {:ok, :pending_manual} ->
        AccessGuardian.Access.mark_pending_manual(request)
        :ok

      {:ok, result} ->
        AccessGuardian.Access.complete_provisioning(request, %{
          adapter_type: to_string(app.integration_type),
          external_account_id: result.external_account_id
        })

        :ok

      {:error, :permanent, reason} ->
        AccessGuardian.Access.fail_provisioning(request, %{
          adapter_type: to_string(app.integration_type),
          error_reason: reason
        })

        :ok

      {:error, :transient, reason} ->
        {:error, reason}
    end
  end
end
