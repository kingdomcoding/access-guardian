defmodule AccessGuardian.Catalog.ApproverResolverTest do
  use AccessGuardian.DataCase
  import AccessGuardian.Factory

  alias AccessGuardian.Catalog.ApproverResolver

  setup do
    org = create_org!()
    manager = create_user!(org, %{full_name: "Manager", org_role: :org_admin})
    employee = create_user!(org, %{full_name: "Employee", manager_id: manager.id})
    %{org: org, manager: manager, employee: employee}
  end

  test "zero-step policy returns empty list", %{org: org, employee: employee} do
    create_policy!(org, [])

    {:ok, app} =
      AccessGuardian.Catalog.create_application(%{organization_id: org.id, name: "App"})

    assert ApproverResolver.resolve(app, employee) == []
  end

  test "manager step resolves to requesting user's manager", %{
    org: org,
    manager: manager,
    employee: employee
  } do
    create_policy!(org, [
      %{step_index: 0, approver_type: :manager, response_mode: :first_to_respond}
    ])

    {:ok, app} =
      AccessGuardian.Catalog.create_application(%{organization_id: org.id, name: "App"})

    chain = ApproverResolver.resolve(app, employee)

    assert length(chain) == 1
    assert hd(chain).approver_ids == [manager.id]
    assert hd(chain).response_mode == :first_to_respond
  end

  test "individual step resolves to specific user", %{org: org, employee: employee} do
    reviewer = create_user!(org, %{full_name: "Reviewer"})

    create_policy!(org, [
      %{
        step_index: 0,
        approver_type: :individual,
        specific_user_id: reviewer.id,
        response_mode: :first_to_respond
      }
    ])

    {:ok, app} =
      AccessGuardian.Catalog.create_application(%{organization_id: org.id, name: "App"})

    chain = ApproverResolver.resolve(app, employee)
    assert length(chain) == 1
    assert hd(chain).approver_ids == [reviewer.id]
  end

  test "no policy returns empty list", %{org: org, employee: employee} do
    {:ok, app} =
      AccessGuardian.Catalog.create_application(%{organization_id: org.id, name: "App"})

    assert ApproverResolver.resolve(app, employee) == []
  end
end
