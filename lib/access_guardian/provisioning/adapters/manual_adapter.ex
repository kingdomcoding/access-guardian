defmodule AccessGuardian.Provisioning.Adapters.ManualAdapter do
  @behaviour AccessGuardian.Provisioning.Adapter

  @impl true
  def provision(_app, _user, _entitlements), do: {:ok, :pending_manual}

  @impl true
  def deprovision(_app, _user), do: :ok
end
