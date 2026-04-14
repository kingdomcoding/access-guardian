defmodule AccessGuardian.Catalog.ApproverResolver do
  require Ash.Query

  def resolve(application, requesting_user) do
    policy = load_policy(application)

    case policy do
      nil -> []
      policy ->
        steps = Map.get(policy, :steps, [])
        if steps == [] or not is_list(steps) do
          []
        else
          Enum.map(steps, fn step ->
            %{
              step_index: step.step_index,
              response_mode: step.response_mode,
              approver_ids: resolve_step(step, application, requesting_user)
            }
          end)
        end
    end
  end

  defp load_policy(application) do
    policy_id = application.approval_policy_id
    org_id = application.organization_id

    policy =
      if policy_id do
        case AccessGuardian.Catalog.get_policy(policy_id) do
          {:ok, p} -> p
          _ -> nil
        end
      else
        Ash.read_one!(
          AccessGuardian.Catalog.ApprovalPolicy
          |> Ash.Query.filter(organization_id == ^org_id and is_default == true)
        )
      end

    if policy do
      case Ash.load(policy, [:steps]) do
        {:ok, loaded} -> loaded
        _ -> policy
      end
    end
  end

  defp resolve_step(step, application, requesting_user) do
    case step.approver_type do
      :manager ->
        if requesting_user.manager_id, do: [requesting_user.manager_id], else: []

      :application_admins ->
        case Ash.load(application, [:admin_assignments]) do
          {:ok, app} -> Enum.map(app.admin_assignments, & &1.user_id)
          _ -> []
        end

      :business_owner ->
        if application.business_owner_id, do: [application.business_owner_id], else: []

      :individual ->
        if step.specific_user_id, do: [step.specific_user_id], else: []
    end
  end
end
