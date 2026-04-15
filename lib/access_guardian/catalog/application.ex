defmodule AccessGuardian.Catalog.Application do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("applications")
    repo(AccessGuardian.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:assigned, :discovered, :ignored])
      default(:assigned)
      allow_nil?(false)
      public?(true)
    end

    attribute :integration_type, :atom do
      constraints(one_of: [:api, :agentic, :scim, :manual])
      default(:manual)
      allow_nil?(false)
      public?(true)
    end

    attribute(:business_owner_id, :uuid, public?: true)
    attribute(:approval_policy_id, :uuid, public?: true)
    attribute(:config, :map, default: %{}, public?: true)
    attribute(:live_integration, :boolean, default: false, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :organization, AccessGuardian.Catalog.Organization do
      attribute_writable?(true)
      public?(true)
    end

    belongs_to :business_owner, AccessGuardian.Catalog.User do
      attribute_writable?(true)
      public?(true)
    end

    belongs_to :approval_policy, AccessGuardian.Catalog.ApprovalPolicy do
      attribute_writable?(true)
      public?(true)
    end

    has_many :resources, AccessGuardian.Catalog.Resource
    has_many :admin_assignments, AccessGuardian.Catalog.ApplicationAdminAssignment
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :organization_id,
        :name,
        :status,
        :integration_type,
        :business_owner_id,
        :approval_policy_id,
        :config,
        :live_integration
      ])
    end

    read :assigned_by_org do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id) and status == :assigned))
      prepare(build(sort: [live_integration: :desc, name: :asc]))
    end
  end
end
