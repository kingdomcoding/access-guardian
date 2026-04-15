defmodule AccessGuardian.Catalog.IntegrationSession do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("integration_sessions")
    repo(AccessGuardian.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :platform, :atom do
      constraints(one_of: [:notion])
      allow_nil?(false)
      public?(true)
    end

    attribute :status, :atom do
      constraints(one_of: [:active, :expired])
      default(:active)
      allow_nil?(false)
      public?(true)
    end

    attribute(:workspace_url, :string, allow_nil?: false, public?: true)
    attribute(:captured_at, :utc_datetime, allow_nil?: false, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :application, AccessGuardian.Catalog.Application do
      attribute_writable?(true)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:platform, :status, :workspace_url, :captured_at, :application_id])
    end

    update :mark_expired do
      require_atomic?(false)
      change set_attribute(:status, :expired)
    end

    update :refresh do
      require_atomic?(false)
      accept([:captured_at])
      change set_attribute(:status, :active)
    end
  end
end
