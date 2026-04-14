defmodule AccessGuardian.Access.Changes.AdvanceApprovalStep do
  use Ash.Resource.Change
  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, request ->
      {:ok, app} = AccessGuardian.Catalog.get_application(request.application_id)
      {:ok, user} = AccessGuardian.Catalog.get_user(request.requested_by_id)
      chain = AccessGuardian.Catalog.ApproverResolver.resolve(app, user)
      current_step = Enum.at(chain, request.current_step_index)

      approvals_at_step =
        AccessGuardian.Access.RequestApproval
        |> Ash.Query.filter(
          access_request_id == ^request.id and
            step_index == ^request.current_step_index and
            decision == :approved
        )
        |> Ash.read!()
        |> length()

      step_complete? = step_complete?(current_step, approvals_at_step)

      cond do
        step_complete? && request.current_step_index + 1 >= request.total_steps ->
          {:ok, updated} =
            request
            |> Ash.Changeset.for_update(:set_approved, %{})
            |> Ash.update()

          Task.start(fn ->
            AccessGuardian.Access.advance_to_provisioning(updated)
          end)

          {:ok, updated}

        step_complete? ->
          request
          |> Ash.Changeset.for_update(:increment_step, %{
            current_step_index: request.current_step_index + 1
          })
          |> Ash.update()

        true ->
          {:ok, request}
      end
    end)
  end

  defp step_complete?(nil, _), do: true
  defp step_complete?(%{response_mode: :first_to_respond}, count) when count >= 1, do: true

  defp step_complete?(%{response_mode: :everyone_must_approve, approver_ids: ids}, count),
    do: count >= length(ids)

  defp step_complete?(_, _), do: false
end
