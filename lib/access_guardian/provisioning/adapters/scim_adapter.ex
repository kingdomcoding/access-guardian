defmodule AccessGuardian.Provisioning.Adapters.ScimAdapter do
  @behaviour AccessGuardian.Provisioning.Adapter

  @impl true
  def provision(_app, _user, _entitlements) do
    Process.sleep(Enum.random(100..500))

    case :rand.uniform(100) do
      n when n <= 5 -> {:error, :transient, "SCIM endpoint unavailable"}
      _ -> {:ok, %{external_account_id: "okta-group-#{Ash.UUID.generate()}"}}
    end
  end

  @impl true
  def deprovision(_app, _user), do: :ok
end
