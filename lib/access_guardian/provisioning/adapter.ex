defmodule AccessGuardian.Provisioning.Adapter do
  @callback provision(app :: map(), user :: map(), entitlements :: map()) ::
              {:ok, %{external_account_id: String.t()}}
              | {:ok, :pending_manual}
              | {:error, :transient, String.t()}
              | {:error, :permanent, String.t()}

  @callback deprovision(app :: map(), user :: map()) ::
              :ok
              | {:error, :transient, String.t()}
              | {:error, :permanent, String.t()}
end
