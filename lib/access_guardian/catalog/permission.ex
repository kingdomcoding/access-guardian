defmodule AccessGuardian.Catalog.Permission do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("permissions")
    repo(AccessGuardian.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:resource_id, :uuid, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)

    attribute :selection_type, :atom do
      constraints(one_of: [:single, :multi])
      default(:single)
      allow_nil?(false)
      public?(true)
    end
  end

  relationships do
    belongs_to :resource, AccessGuardian.Catalog.Resource do
      attribute_writable?(true)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:resource_id, :name, :selection_type])
    end
  end
end
