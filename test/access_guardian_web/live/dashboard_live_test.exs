defmodule AccessGuardianWeb.DashboardLiveTest do
  use AccessGuardianWeb.ConnCase
  import Phoenix.LiveViewTest
  import AccessGuardian.Factory

  setup do
    org = create_org!()
    manager = create_user!(org, %{full_name: "Manager", org_role: :org_admin})
    employee = create_user!(org, %{full_name: "Employee", manager_id: manager.id})
    app = create_app!(org, %{name: "TestApp"})

    create_policy!(org, [
      %{step_index: 0, approver_type: :manager, response_mode: :first_to_respond}
    ])

    AccessGuardian.Access.create_request(%{
      organization_id: org.id,
      affected_user_id: employee.id,
      requested_by_id: employee.id,
      application_id: app.id,
      request_reason: "Need access"
    })

    :ok
  end

  test "renders dashboard with stats", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "Dashboard"
    assert html =~ "Pipeline"
    assert html =~ "Granted"
    assert html =~ "Needs Attention"
  end

  test "shows recent requests", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "Employee"
    assert html =~ "TestApp"
  end
end
