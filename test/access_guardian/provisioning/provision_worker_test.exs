defmodule AccessGuardian.Provisioning.ProvisionWorkerTest do
  use AccessGuardian.DataCase
  import AccessGuardian.Factory

  alias AccessGuardian.Provisioning.ProvisionWorker

  setup do
    org = create_org!()

    create_policy!(org, [
      %{step_index: 0, approver_type: :manager, response_mode: :first_to_respond}
    ])

    manager = create_user!(org, %{full_name: "Manager", org_role: :org_admin})
    employee = create_user!(org, %{full_name: "Employee", manager_id: manager.id})

    %{org: org, manager: manager, employee: employee}
  end

  defp create_provisioning_request(ctx, integration_type) do
    app =
      create_app!(ctx.org, %{name: "App-#{integration_type}", integration_type: integration_type})

    {:ok, request} =
      AccessGuardian.Access.create_request(%{
        organization_id: ctx.org.id,
        affected_user_id: ctx.employee.id,
        requested_by_id: ctx.employee.id,
        application_id: app.id,
        request_reason: "test"
      })

    {:ok, approved} =
      AccessGuardian.Access.approve_request(request, %{approver_id: ctx.manager.id})

    Process.sleep(50)
    {:ok, latest} = AccessGuardian.Access.get_request(approved.id)

    latest =
      if latest.status == :approved do
        {:ok, advanced} = AccessGuardian.Access.advance_to_provisioning(latest)
        advanced
      else
        latest
      end

    latest
  end

  test "provisions via manual adapter and marks pending_manual", ctx do
    request = create_provisioning_request(ctx, :manual)
    assert request.status == :provisioning

    :ok = ProvisionWorker.perform(%Oban.Job{args: %{"request_id" => request.id}})

    {:ok, updated} = AccessGuardian.Access.get_request(request.id)
    assert updated.pending_manual == true
    assert updated.provisioner_type == "manual"
  end

  test "provisions via scim adapter (low failure rate)", ctx do
    request = create_provisioning_request(ctx, :scim)
    assert request.status == :provisioning

    result = ProvisionWorker.perform(%Oban.Job{args: %{"request_id" => request.id}})

    {:ok, updated} = AccessGuardian.Access.get_request(request.id)
    assert result == :ok
    assert updated.status in [:granted, :rejected]
  end
end
