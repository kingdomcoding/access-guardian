defmodule AccessGuardian.Catalog.Organization do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "organizations"
    repo AccessGuardian.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :slug, :string, allow_nil?: false, public?: true
    attribute :slack_hr_channel_id, :string, public?: true
    attribute :slack_admin_channel_id, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :slug, :slack_hr_channel_id, :slack_admin_channel_id]
    end
  end
end
