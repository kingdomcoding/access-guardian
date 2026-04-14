defmodule AccessGuardian.Provisioning.ProvisionWorker do
  use Oban.Worker, queue: :provisioning, max_attempts: 8

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => _request_id}}) do
    :ok
  end
end
