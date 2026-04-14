defmodule AccessGuardian.Catalog.ApprovalPolicy do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("approval_policies")
    repo(AccessGuardian.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:is_default, :boolean, default: false, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :organization, AccessGuardian.Catalog.Organization do
      attribute_writable?(true)
      public?(true)
    end

    has_many :steps, AccessGuardian.Catalog.ApprovalStep do
      sort(step_index: :asc)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:organization_id, :name, :is_default])
    end

    read :default_for_org do
      argument(:organization_id, :uuid, allow_nil?: false)
      get?(true)
      filter(expr(organization_id == ^arg(:organization_id) and is_default == true))
    end
  end
end
