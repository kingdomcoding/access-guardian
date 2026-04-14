defmodule AccessGuardianWeb.SlackController do
  use AccessGuardianWeb, :controller

  alias AccessGuardian.Slack.{BlockKit, ApiClient}

  plug AccessGuardianWeb.Plugs.SlackSignature

  def commands(conn, %{"command" => "/request", "trigger_id" => trigger_id}) do
    org = get_org()
    {:ok, apps} = AccessGuardian.Catalog.list_applications_by_org(org.id)
    modal = BlockKit.request_modal(apps)
    ApiClient.open_modal(trigger_id, modal)
    send_resp(conn, 200, "")
  end

  def commands(conn, _params) do
    send_resp(conn, 200, "Unknown command")
  end

  def interactions(conn, _params) do
    payload = conn.params["payload"] |> Jason.decode!()
    handle_interaction(conn, payload)
  end

  def events(conn, %{"type" => "url_verification", "challenge" => challenge}) do
    json(conn, %{challenge: challenge})
  end

  def events(conn, _params) do
    send_resp(conn, 200, "")
  end

  defp handle_interaction(conn, %{"type" => "view_submission", "callback_id" => "submit_request"} = payload) do
    slack_user_id = get_in(payload, ["user", "id"])
    {:ok, user} = AccessGuardian.Catalog.get_user_by_slack_id(slack_user_id)

    values = get_in(payload, ["view", "state", "values"])
    app_id = get_in(values, ["app_block", "application_id", "selected_option", "value"])
    reason = get_in(values, ["reason_block", "reason", "value"])

    case AccessGuardian.Access.create_request(%{
           organization_id: user.organization_id,
           affected_user_id: user.id,
           requested_by_id: user.id,
           application_id: app_id,
           request_reason: reason
         }) do
      {:ok, _request} ->
        json(conn, %{response_action: "clear"})

      {:error, _} ->
        json(conn, %{
          response_action: "errors",
          errors: %{reason_block: "Failed to create request"}
        })
    end
  end

  defp handle_interaction(conn, %{"type" => "block_actions", "actions" => [action | _]} = payload) do
    action_id = action["action_id"]
    slack_user_id = get_in(payload, ["user", "id"])
    {:ok, user} = AccessGuardian.Catalog.get_user_by_slack_id(slack_user_id)
    channel = get_in(payload, ["channel", "id"])
    message_ts = get_in(payload, ["message", "ts"])

    cond do
      String.starts_with?(action_id, "approve_request:") ->
        request_id = String.replace_prefix(action_id, "approve_request:", "")
        {:ok, request} = AccessGuardian.Access.get_request(request_id)
        AccessGuardian.Access.approve_request(request, %{approver_id: user.id})
        ApiClient.update_message(channel, message_ts, BlockKit.approved_update(user.full_name))

      String.starts_with?(action_id, "deny_request:") ->
        request_id = String.replace_prefix(action_id, "deny_request:", "")
        {:ok, request} = AccessGuardian.Access.get_request(request_id)
        AccessGuardian.Access.deny_request(request, %{denier_id: user.id, reason: "Denied via Slack"})

        ApiClient.update_message(
          channel,
          message_ts,
          BlockKit.denied_update(user.full_name, "Denied via Slack")
        )

      String.starts_with?(action_id, "manual_grant:") ->
        request_id = String.replace_prefix(action_id, "manual_grant:", "")
        {:ok, request} = AccessGuardian.Access.get_request(request_id)
        AccessGuardian.Access.complete_manual_grant(request, %{admin_id: user.id})

        ApiClient.update_message(channel, message_ts, [
          %{
            type: "section",
            text: %{type: "mrkdwn", text: "✅ *Granted* by #{user.full_name}"}
          }
        ])

      String.starts_with?(action_id, "manual_reject:") ->
        request_id = String.replace_prefix(action_id, "manual_reject:", "")
        {:ok, request} = AccessGuardian.Access.get_request(request_id)

        AccessGuardian.Access.reject_manual_grant(request, %{
          admin_id: user.id,
          reason: "Rejected via Slack"
        })

        ApiClient.update_message(channel, message_ts, [
          %{
            type: "section",
            text: %{type: "mrkdwn", text: "❌ *Rejected* by #{user.full_name}"}
          }
        ])

      true ->
        :ok
    end

    send_resp(conn, 200, "")
  end

  defp handle_interaction(conn, _payload) do
    send_resp(conn, 200, "")
  end

  defp get_org do
    {:ok, [org | _]} = Ash.read(AccessGuardian.Catalog.Organization)
    org
  end
end
