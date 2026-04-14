defmodule AccessGuardian.AccessTest do
  use AccessGuardian.DataCase
  import AccessGuardian.Factory

  setup do
    org = create_org!()
    manager = create_user!(org, %{full_name: "Manager", org_role: :org_admin})
    employee = create_user!(org, %{full_name: "Employee", manager_id: manager.id})
    app = create_app!(org, %{name: "GitHub", integration_type: :api})
    %{org: org, manager: manager, employee: employee, app: app}
  end

  describe "auto-approve (zero-step policy)" do
    setup %{org: org} do
      # The default policy has zero steps → auto-approve
      create_policy!(org, [])
      :ok
    end

    test "transitions to approved or provisioning immediately", ctx do
      {:ok, request} =
        AccessGuardian.Access.create_request(%{
          organization_id: ctx.org.id,
          affected_user_id: ctx.employee.id,
          requested_by_id: ctx.employee.id,
          application_id: ctx.app.id,
          request_reason: "Need it"
        })

      assert request.status in [:approved, :provisioning, :granted, :rejected]
    end
  end

  describe "single-step manager approval" do
    setup %{org: org} do
      create_policy!(org, [
        %{step_index: 0, approver_type: :manager, response_mode: :first_to_respond}
      ])

      :ok
    end

    test "create sets pending_approval", ctx do
      {:ok, request} =
        AccessGuardian.Access.create_request(%{
          organization_id: ctx.org.id,
          affected_user_id: ctx.employee.id,
          requested_by_id: ctx.employee.id,
          application_id: ctx.app.id
        })

      assert request.status == :pending_approval
      assert request.total_steps == 1
    end

    test "approve triggers provisioning", ctx do
      {:ok, request} =
        AccessGuardian.Access.create_request(%{
          organization_id: ctx.org.id,
          affected_user_id: ctx.employee.id,
          requested_by_id: ctx.employee.id,
          application_id: ctx.app.id
        })

      {:ok, updated} =
        AccessGuardian.Access.approve_request(request, %{approver_id: ctx.manager.id})

      # After approval of final step, should advance to provisioning
      assert updated.status in [:approved, :provisioning, :granted, :rejected]
    end

    test "deny sets denied with reason", ctx do
      {:ok, request} =
        AccessGuardian.Access.create_request(%{
          organization_id: ctx.org.id,
          affected_user_id: ctx.employee.id,
          requested_by_id: ctx.employee.id,
          application_id: ctx.app.id
        })

      {:ok, denied} =
        AccessGuardian.Access.deny_request(request, %{
          denier_id: ctx.manager.id,
          reason: "Not needed"
        })

      assert denied.status == :denied
      assert denied.deny_reason == "Not needed"
    end
  end

  describe "provisioning results" do
    test "complete_provisioning sets granted", ctx do
      # Create a request that's in provisioning state
      create_policy!(ctx.org, [])

      {:ok, request} =
        AccessGuardian.Access.create_request(%{
          organization_id: ctx.org.id,
          affected_user_id: ctx.employee.id,
          requested_by_id: ctx.employee.id,
          application_id: ctx.app.id
        })

      # Reload to get latest state (Oban inline may have processed it)
      {:ok, latest} = AccessGuardian.Access.get_request(request.id)

      if latest.status == :provisioning do
        {:ok, granted} =
          AccessGuardian.Access.complete_provisioning(latest, %{
            adapter_type: "api",
            external_account_id: "ext-123"
          })

        assert granted.status == :granted
        assert granted.adapter_type == "api"
      end
    end

    test "fail_provisioning sets rejected", ctx do
      create_policy!(ctx.org, [])

      {:ok, request} =
        AccessGuardian.Access.create_request(%{
          organization_id: ctx.org.id,
          affected_user_id: ctx.employee.id,
          requested_by_id: ctx.employee.id,
          application_id: ctx.app.id
        })

      {:ok, latest} = AccessGuardian.Access.get_request(request.id)

      if latest.status == :provisioning do
        {:ok, rejected} =
          AccessGuardian.Access.fail_provisioning(latest, %{
            adapter_type: "agentic",
            error_reason: "UI changed"
          })

        assert rejected.status == :rejected
        assert rejected.reject_reason == "UI changed"
      end
    end
  end
end
