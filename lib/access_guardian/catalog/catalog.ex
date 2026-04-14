defmodule AccessGuardian.Catalog do
  use Ash.Domain

  resources do
    resource AccessGuardian.Catalog.Organization do
      define(:get_organization, action: :read, get_by: [:id])
      define(:create_organization, action: :create)
    end

    resource AccessGuardian.Catalog.User do
      define(:get_user, action: :read, get_by: [:id])
      define(:get_user_by_slack_id, action: :by_slack_id, args: [:slack_user_id])
      define(:list_users_by_org, action: :by_org, args: [:organization_id])
      define(:create_user, action: :create)
    end

    resource AccessGuardian.Catalog.Application do
      define(:get_application, action: :read, get_by: [:id])
      define(:list_applications_by_org, action: :assigned_by_org, args: [:organization_id])
      define(:create_application, action: :create)
    end

    resource AccessGuardian.Catalog.Resource do
      define(:create_resource, action: :create)
    end

    resource AccessGuardian.Catalog.Permission do
      define(:create_permission, action: :create)
    end

    resource AccessGuardian.Catalog.ApprovalPolicy do
      define(:get_policy, action: :read, get_by: [:id])
      define(:create_policy, action: :create)
    end

    resource AccessGuardian.Catalog.ApprovalStep do
      define(:create_step, action: :create)
    end

    resource AccessGuardian.Catalog.ApplicationAdminAssignment do
      define(:create_admin_assignment, action: :create)
    end

    resource AccessGuardian.Catalog.AppAccount do
      define(:create_app_account, action: :create)
      define(:active_for_user, action: :active_for_user, args: [:user_id])
    end
  end
end
