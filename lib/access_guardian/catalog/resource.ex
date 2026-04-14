defmodule AccessGuardian.Catalog.Resource do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "resources"
    repo AccessGuardian.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :application_id, :uuid, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :parent_resource_id, :uuid, public?: true
    attribute :is_mandatory, :boolean, default: false, public?: true
    attribute :is_requestable, :boolean, default: true, public?: true
  end

  relationships do
    belongs_to :application, AccessGuardian.Catalog.Application do
      attribute_writable? true
      public? true
    end

    belongs_to :parent_resource, __MODULE__ do
      attribute_writable? true
      source_attribute :parent_resource_id
      destination_attribute :id
      public? true
    end

    has_many :permissions, AccessGuardian.Catalog.Permission
  end

  actions do
    defaults [:read]

    create :create do
      accept [:application_id, :name, :parent_resource_id, :is_mandatory, :is_requestable]
    end
  end
end
