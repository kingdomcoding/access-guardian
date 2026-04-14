defmodule AccessGuardian.Provisioning.Adapters.ApiAdapter do
  @behaviour AccessGuardian.Provisioning.Adapter

  @impl true
  def provision(_app, _user, _entitlements) do
    Process.sleep(Enum.random(200..2000))

    case :rand.uniform(100) do
      n when n <= 2 -> {:error, :permanent, "Account conflict — user already exists"}
      n when n <= 12 -> {:error, :transient, "API timeout — 503 Service Unavailable"}
      _ -> {:ok, %{external_account_id: "api-#{Ash.UUID.generate()}"}}
    end
  end

  @impl true
  def deprovision(_app, _user) do
    Process.sleep(Enum.random(200..1000))
    :ok
  end
end
