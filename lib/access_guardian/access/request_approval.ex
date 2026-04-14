defmodule AccessGuardian.Access.RequestApproval do
  use Ash.Resource,
    domain: AccessGuardian.Access,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("request_approvals")
    repo(AccessGuardian.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:access_request_id, :uuid, allow_nil?: false, public?: true)
    attribute(:approver_id, :uuid, allow_nil?: false, public?: true)
    attribute(:step_index, :integer, allow_nil?: false, public?: true)

    attribute :decision, :atom do
      constraints(one_of: [:approved, :denied])
      allow_nil?(false)
      public?(true)
    end

    attribute(:override_by_id, :uuid, public?: true)
    attribute(:decided_at, :utc_datetime, allow_nil?: false, public?: true)
  end

  relationships do
    belongs_to :access_request, AccessGuardian.Access.AccessRequest do
      attribute_writable?(true)
      public?(true)
    end

    belongs_to :approver, AccessGuardian.Catalog.User do
      attribute_writable?(true)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :access_request_id,
        :approver_id,
        :step_index,
        :decision,
        :override_by_id,
        :decided_at
      ])
    end
  end
end
