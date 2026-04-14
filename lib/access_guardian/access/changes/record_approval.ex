defmodule AccessGuardian.Access.Changes.RecordApproval do
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, request ->
      approver_id = Ash.Changeset.get_argument(changeset, :approver_id)
      override_by_id = Ash.Changeset.get_argument(changeset, :override_by_id)

      AccessGuardian.Access.RequestApproval
      |> Ash.Changeset.for_create(:create, %{
        access_request_id: request.id,
        approver_id: approver_id,
        step_index: request.current_step_index,
        decision: :approved,
        override_by_id: override_by_id,
        decided_at: DateTime.utc_now()
      })
      |> Ash.create!()

      {:ok, request}
    end)
  end
end
