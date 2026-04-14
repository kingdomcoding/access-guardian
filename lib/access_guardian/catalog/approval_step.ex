defmodule AccessGuardian.Catalog.ApprovalStep do
  use Ash.Resource,
    domain: AccessGuardian.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("approval_steps")
    repo(AccessGuardian.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:approval_policy_id, :uuid, allow_nil?: false, public?: true)
    attribute(:step_index, :integer, allow_nil?: false, public?: true)

    attribute :approver_type, :atom do
      constraints(one_of: [:manager, :application_admins, :business_owner, :individual])
      allow_nil?(false)
      public?(true)
    end

    attribute(:specific_user_id, :uuid, public?: true)

    attribute :response_mode, :atom do
      constraints(one_of: [:first_to_respond, :everyone_must_approve])
      default(:first_to_respond)
      allow_nil?(false)
      public?(true)
    end
  end

  relationships do
    belongs_to :approval_policy, AccessGuardian.Catalog.ApprovalPolicy do
      attribute_writable?(true)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :approval_policy_id,
        :step_index,
        :approver_type,
        :specific_user_id,
        :response_mode
      ])
    end
  end
end
