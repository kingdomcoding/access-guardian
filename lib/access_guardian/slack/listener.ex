defmodule AccessGuardian.Slack.Listener do
  use GenServer

  alias AccessGuardian.Slack.{ApiClient, BlockKit}

  def start_link(_opts) do
    if Application.get_env(:access_guardian, :slack_enabled) do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    else
      :ignore
    end
  end

  @impl true
  def init(_) do
    AccessGuardianWeb.Endpoint.subscribe("access_requests:created")
    AccessGuardianWeb.Endpoint.subscribe("access_requests:updated")
    {:ok, %{}}
  end

  @impl true
  def handle_info(%{topic: "access_requests:" <> _, payload: %{data: request}}, state) do
    Task.Supervisor.start_child(AccessGuardian.SlackTaskSupervisor, fn ->
      request = load_full_request(request.id)
      handle_request_event(request)
    end)

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp handle_request_event(request) do
    case request.status do
      :pending_approval -> notify_approvers(request)
      :granted -> notify_requester(request, :granted)
      :rejected -> notify_requester(request, :rejected)
      :provisioning when request.pending_manual -> notify_manual_admins(request)
      _ -> :ok
    end
  end

  defp notify_approvers(request) do
    {:ok, app} = AccessGuardian.Catalog.get_application(request.application_id)
    {:ok, user} = AccessGuardian.Catalog.get_user(request.requested_by_id)
    chain = AccessGuardian.Catalog.ApproverResolver.resolve(app, user)
    current = Enum.at(chain, request.current_step_index)

    if current do
      Enum.each(current.approver_ids, fn id ->
        {:ok, approver} = AccessGuardian.Catalog.get_user(id)

        if approver.slack_user_id do
          blocks = BlockKit.approval_request_dm(request)
          ApiClient.post_message(approver.slack_user_id, blocks, text: "New access request")
        end
      end)
    end
  end

  defp notify_requester(request, outcome) do
    if request.affected_user && request.affected_user.slack_user_id do
      blocks = BlockKit.provisioning_result_dm(request, outcome)
      ApiClient.post_message(to_string(request.affected_user.slack_user_id), blocks)
    end
  end

  defp notify_manual_admins(request) do
    {:ok, app} = AccessGuardian.Catalog.get_application(request.application_id)
    {:ok, app} = Ash.load(app, [:admin_assignments])

    Enum.each(app.admin_assignments, fn assignment ->
      {:ok, admin} = AccessGuardian.Catalog.get_user(assignment.user_id)

      if admin.slack_user_id do
        blocks = BlockKit.manual_grant_dm(request, admin.full_name)
        ApiClient.post_message(admin.slack_user_id, blocks, text: "Manual provisioning needed")
      end
    end)
  end

  defp load_full_request(id) do
    {:ok, r} = AccessGuardian.Access.get_request(id)
    {:ok, r} = Ash.load(r, [:affected_user, :requested_by, :application])
    r
  end
end
