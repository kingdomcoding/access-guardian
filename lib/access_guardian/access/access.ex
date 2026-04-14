defmodule AccessGuardian.Access do
  use Ash.Domain

  resources do
    resource AccessGuardian.Access.AccessRequest do
      define :get_request, action: :read, get_by: [:id]
      define :create_request, action: :create
      define :approve_request, action: :approve
      define :deny_request, action: :deny
      define :advance_to_provisioning, action: :advance_to_provisioning
      define :complete_provisioning, action: :complete_provisioning
      define :fail_provisioning, action: :fail_provisioning
      define :mark_pending_manual, action: :mark_pending_manual
      define :complete_manual_grant, action: :complete_manual_grant
      define :reject_manual_grant, action: :reject_manual_grant
      define :list_by_org, action: :by_org, args: [:organization_id]
    end

    resource AccessGuardian.Access.RequestApproval
  end
end
