defmodule AccessGuardian.Access.AccessRequest do
  use Ash.Resource,
    domain: AccessGuardian.Access,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table("access_requests")
    repo(AccessGuardian.Repo)

    custom_indexes do
      index([:organization_id, :status])
      index([:application_id])
      index([:affected_user_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:organization_id, :uuid, allow_nil?: false, public?: true)
    attribute(:affected_user_id, :uuid, allow_nil?: false, public?: true)
    attribute(:requested_by_id, :uuid, allow_nil?: false, public?: true)
    attribute(:application_id, :uuid, allow_nil?: false, public?: true)

    attribute :status, :atom do
      constraints(
        one_of: [:pending_approval, :approved, :provisioning, :granted, :rejected, :denied]
      )

      default(:pending_approval)
      allow_nil?(false)
      public?(true)
    end

    attribute(:request_reason, :string, public?: true)
    attribute(:entitlements, :map, default: %{}, public?: true)
    attribute(:current_step_index, :integer, default: 0, public?: true)
    attribute(:total_steps, :integer, default: 0, public?: true)
    attribute(:approved_at, :utc_datetime, public?: true)
    attribute(:denied_at, :utc_datetime, public?: true)
    attribute(:denied_by_id, :uuid, public?: true)
    attribute(:deny_reason, :string, public?: true)
    attribute(:granted_at, :utc_datetime, public?: true)
    attribute(:rejected_at, :utc_datetime, public?: true)
    attribute(:reject_reason, :string, public?: true)
    attribute(:provisioner_type, :string, public?: true)
    attribute(:adapter_type, :string, public?: true)
    attribute(:external_account_id, :string, public?: true)
    attribute(:pending_manual, :boolean, default: false, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :affected_user, AccessGuardian.Catalog.User do
      attribute_writable?(true)
      public?(true)
    end

    belongs_to :requested_by, AccessGuardian.Catalog.User do
      attribute_writable?(true)
      source_attribute(:requested_by_id)
      public?(true)
    end

    belongs_to :application, AccessGuardian.Catalog.Application do
      attribute_writable?(true)
      public?(true)
    end

    has_many :approvals, AccessGuardian.Access.RequestApproval do
      sort(decided_at: :asc)
    end
  end

  pub_sub do
    module(AccessGuardianWeb.Endpoint)
    prefix("access_requests")

    publish(:create, "created")
    publish(:approve, "updated")
    publish(:deny, "updated")
    publish(:advance_to_provisioning, "updated")
    publish(:complete_provisioning, "updated")
    publish(:fail_provisioning, "updated")
    publish(:mark_pending_manual, "updated")
    publish(:complete_manual_grant, "updated")
    publish(:reject_manual_grant, "updated")
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :organization_id,
        :affected_user_id,
        :requested_by_id,
        :application_id,
        :request_reason,
        :entitlements
      ])

      change({AccessGuardian.Access.Changes.ResolveApprovalChain, []})
      change({AccessGuardian.Access.Changes.AutoApproveIfNoSteps, []})
    end

    update :approve do
      require_atomic?(false)
      argument(:approver_id, :uuid, allow_nil?: false)
      argument(:override_by_id, :uuid)

      validate({AccessGuardian.Access.Validations.RequireStatus, status: :pending_approval})

      change({AccessGuardian.Access.Changes.RecordApproval, []})
      change({AccessGuardian.Access.Changes.AdvanceApprovalStep, []})
    end

    update :deny do
      require_atomic?(false)
      argument(:denier_id, :uuid, allow_nil?: false)
      argument(:reason, :string)

      validate({AccessGuardian.Access.Validations.RequireStatus, status: :pending_approval})

      change(set_attribute(:status, :denied))
      change(set_attribute(:denied_at, &DateTime.utc_now/0))

      change(fn changeset, _ctx ->
        changeset
        |> Ash.Changeset.force_change_attribute(
          :denied_by_id,
          Ash.Changeset.get_argument(changeset, :denier_id)
        )
        |> Ash.Changeset.force_change_attribute(
          :deny_reason,
          Ash.Changeset.get_argument(changeset, :reason)
        )
      end)
    end

    update :advance_to_provisioning do
      require_atomic?(false)
      change(set_attribute(:status, :provisioning))
      change({AccessGuardian.Access.Changes.EnqueueProvisioning, []})
    end

    update :set_approved do
      require_atomic?(false)
      change(set_attribute(:status, :approved))
      change(set_attribute(:approved_at, &DateTime.utc_now/0))
    end

    update :increment_step do
      accept([:current_step_index])
    end

    update :complete_provisioning do
      require_atomic?(false)
      argument(:adapter_type, :string)
      argument(:external_account_id, :string)

      change(set_attribute(:status, :granted))
      change(set_attribute(:granted_at, &DateTime.utc_now/0))
      change(set_attribute(:provisioner_type, "automation"))

      change(fn changeset, _ctx ->
        changeset
        |> Ash.Changeset.force_change_attribute(
          :adapter_type,
          Ash.Changeset.get_argument(changeset, :adapter_type)
        )
        |> Ash.Changeset.force_change_attribute(
          :external_account_id,
          Ash.Changeset.get_argument(changeset, :external_account_id)
        )
      end)

      change({AccessGuardian.Access.Changes.CreateAppAccount, []})
    end

    update :fail_provisioning do
      require_atomic?(false)
      argument(:adapter_type, :string)
      argument(:error_reason, :string)

      change(set_attribute(:status, :rejected))
      change(set_attribute(:rejected_at, &DateTime.utc_now/0))

      change(fn changeset, _ctx ->
        changeset
        |> Ash.Changeset.force_change_attribute(
          :adapter_type,
          Ash.Changeset.get_argument(changeset, :adapter_type)
        )
        |> Ash.Changeset.force_change_attribute(
          :reject_reason,
          Ash.Changeset.get_argument(changeset, :error_reason)
        )
      end)
    end

    update :mark_pending_manual do
      require_atomic?(false)
      change(set_attribute(:pending_manual, true))
      change(set_attribute(:provisioner_type, "manual"))
    end

    update :complete_manual_grant do
      require_atomic?(false)
      argument(:admin_id, :uuid)

      change(set_attribute(:status, :granted))
      change(set_attribute(:granted_at, &DateTime.utc_now/0))
      change(set_attribute(:provisioner_type, "manual"))
      change(set_attribute(:pending_manual, false))

      change({AccessGuardian.Access.Changes.CreateAppAccount, []})
    end

    update :reject_manual_grant do
      require_atomic?(false)
      argument(:admin_id, :uuid)
      argument(:reason, :string)

      change(set_attribute(:status, :rejected))
      change(set_attribute(:rejected_at, &DateTime.utc_now/0))
      change(set_attribute(:pending_manual, false))

      change(fn changeset, _ctx ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :reject_reason,
          Ash.Changeset.get_argument(changeset, :reason)
        )
      end)
    end

    read :by_org do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id)))

      prepare(
        build(sort: [inserted_at: :desc], load: [:affected_user, :requested_by, :application])
      )
    end

    read :search do
      argument(:organization_id, :uuid, allow_nil?: false)
      argument(:query, :string, allow_nil?: false)

      filter(expr(organization_id == ^arg(:organization_id)))

      prepare(
        build(sort: [inserted_at: :desc], load: [:affected_user, :requested_by, :application])
      )
    end
  end
end
