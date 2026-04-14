defmodule AccessGuardian.Catalog.User do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("users")
    repo(AccessGuardian.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:email, :ci_string, allow_nil?: false, public?: true)
    attribute(:full_name, :string, allow_nil?: false, public?: true)
    attribute(:department, :string, public?: true)
    attribute(:job_title, :string, public?: true)
    attribute(:manager_id, :uuid, public?: true)
    attribute(:slack_user_id, :string, public?: true)

    attribute :org_role, :atom do
      constraints(one_of: [:org_admin, :hr_user, :user])
      default(:user)
      allow_nil?(false)
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :organization, AccessGuardian.Catalog.Organization do
      attribute_writable?(true)
      public?(true)
    end

    belongs_to :manager, __MODULE__ do
      attribute_writable?(true)
      source_attribute(:manager_id)
      destination_attribute(:id)
      public?(true)
    end
  end

  identities do
    identity(:unique_email_per_org, [:organization_id, :email])
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :organization_id,
        :email,
        :full_name,
        :department,
        :job_title,
        :manager_id,
        :slack_user_id,
        :org_role
      ])
    end

    update :update do
      accept([:full_name, :department, :job_title, :manager_id, :slack_user_id, :org_role])
    end

    read :by_org do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id)))
    end

    read :by_slack_id do
      argument(:slack_user_id, :string, allow_nil?: false)
      get?(true)
      filter(expr(slack_user_id == ^arg(:slack_user_id)))
    end
  end
end
