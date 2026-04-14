defmodule AccessGuardian.Catalog.ApplicationAdminAssignment do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("application_admin_assignments")
    repo(AccessGuardian.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:application_id, :uuid, allow_nil?: false, public?: true)
    attribute(:user_id, :uuid, allow_nil?: false, public?: true)
  end

  relationships do
    belongs_to :application, AccessGuardian.Catalog.Application do
      attribute_writable?(true)
      public?(true)
    end

    belongs_to :user, AccessGuardian.Catalog.User do
      attribute_writable?(true)
      public?(true)
    end
  end

  identities do
    identity(:unique_admin_assignment, [:application_id, :user_id])
  end

  actions do
    defaults([:read])

    create :create do
      accept([:application_id, :user_id])
    end
  end
end
