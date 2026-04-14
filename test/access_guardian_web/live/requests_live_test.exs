defmodule AccessGuardianWeb.RequestsLiveTest do
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

    {:ok, request} =
      AccessGuardian.Access.create_request(%{
        organization_id: org.id,
        affected_user_id: employee.id,
        requested_by_id: employee.id,
        application_id: app.id,
        request_reason: "Need access"
      })

    %{request: request, manager: manager}
  end

  test "renders request list", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/requests")

    assert html =~ "Access Requests"
    assert html =~ "Employee"
    assert html =~ "TestApp"
  end

  test "selecting a request shows detail panel", %{conn: conn, request: request} do
    {:ok, view, _html} = live(conn, "/requests")

    html =
      view
      |> element(~s([phx-click="select"][phx-value-id="#{request.id}"]))
      |> render_click()

    assert html =~ "Request Detail"
    assert html =~ "Employee"
    assert html =~ "TestApp"
  end

  test "filtering by status works", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/requests")

    html =
      view
      |> form("form[phx-change=filter]")
      |> render_change(%{status: "granted"})

    assert html =~ "No requests found"
  end
end
