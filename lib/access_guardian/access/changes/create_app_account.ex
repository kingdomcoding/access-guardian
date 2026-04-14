defmodule AccessGuardian.Access.Changes.CreateAppAccount do
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, request ->
      AccessGuardian.Catalog.create_app_account(%{
        user_id: request.affected_user_id,
        application_id: request.application_id,
        status: :active,
        provisioned_at: DateTime.utc_now()
      })

      {:ok, request}
    end)
  end
end
