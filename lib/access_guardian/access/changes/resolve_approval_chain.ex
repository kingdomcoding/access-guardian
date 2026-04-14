defmodule AccessGuardian.Access.Changes.ResolveApprovalChain do
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    app_id = Ash.Changeset.get_attribute(changeset, :application_id)
    user_id = Ash.Changeset.get_attribute(changeset, :requested_by_id)

    with {:ok, app} <- AccessGuardian.Catalog.get_application(app_id),
         {:ok, user} <- AccessGuardian.Catalog.get_user(user_id) do
      chain = AccessGuardian.Catalog.ApproverResolver.resolve(app, user)
      total_steps = length(chain)

      changeset
      |> Ash.Changeset.force_change_attribute(:total_steps, total_steps)
      |> Ash.Changeset.set_context(%{approval_chain: chain})
    else
      _ ->
        Ash.Changeset.add_error(changeset, field: :application_id, message: "application or user not found")
    end
  end
end
