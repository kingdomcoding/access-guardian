defmodule AccessGuardian.Catalog.AppAccount do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "app_accounts"
    repo AccessGuardian.Repo

    custom_indexes do
      index [:user_id, :application_id], unique: true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid, allow_nil?: false, public?: true
    attribute :application_id, :uuid, allow_nil?: false, public?: true

    attribute :status, :atom do
      constraints one_of: [:active, :pending, :revoked]
      default :active
      allow_nil? false
      public? true
    end

    attribute :permissions_snapshot, :map, default: %{}, public?: true
    attribute :provisioned_at, :utc_datetime, public?: true
    attribute :revoked_at, :utc_datetime, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read]

    create :create do
      accept [:user_id, :application_id, :status, :permissions_snapshot, :provisioned_at]
    end

    read :active_for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and status == :active)
    end
  end
end
