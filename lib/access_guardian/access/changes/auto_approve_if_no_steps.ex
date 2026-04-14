defmodule AccessGuardian.Access.Changes.AutoApproveIfNoSteps do
  use Ash.Resource.Change

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    total_steps = Ash.Changeset.get_attribute(changeset, :total_steps)

    if total_steps == 0 do
      changeset
      |> Ash.Changeset.force_change_attribute(:status, :approved)
      |> Ash.Changeset.force_change_attribute(:approved_at, DateTime.utc_now())
      |> Ash.Changeset.after_action(fn _cs, record ->
        Task.start(fn ->
          AccessGuardian.Access.advance_to_provisioning(record)
        end)

        {:ok, record}
      end)
    else
      changeset
    end
  end
end
