defmodule AccessGuardian.Access.Changes.EnqueueProvisioning do
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, request ->
      AccessGuardian.Provisioning.ProvisionWorker.new(%{request_id: request.id})
      |> Oban.insert!()

      {:ok, request}
    end)
  end
end
