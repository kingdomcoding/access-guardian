defmodule AccessGuardian.Slack.BlockKit do
  def request_confirmed_dm(request) do
    [
      section("✅ *Access request submitted* for *#{request.application.name}*"),
      section("Your request is being reviewed. You'll be notified when it's approved or denied.")
    ]
  end

  def approval_request_dm(request) do
    [
      section("*New access request*"),
      fields([
        {"Requester", request.affected_user.full_name},
        {"Application", request.application.name},
        {"Reason", request.request_reason || "No reason provided"}
      ]),
      actions([
        button("Approve", "approve_request:#{request.id}", "primary"),
        button("Deny", "deny_request:#{request.id}", "danger")
      ])
    ]
  end

  def provisioning_result_dm(request, :granted) do
    msg =
      case request.adapter_type do
        "github_api" ->
          "📧 An invitation to *#{request.application.name}* has been sent to your email. Check your inbox and accept it to get access."

        "notion_playwright" ->
          "📧 An invitation to *#{request.application.name}* has been sent to your email."

        _ ->
          "✅ *Access granted* to *#{request.application.name}*. You're all set."
      end

    [section(msg)]
  end

  def provisioning_result_dm(request, :rejected) do
    reason = request.reject_reason || "Unknown error"

    [
      section(
        "❌ *Access to #{request.application.name} could not be provisioned.* Reason: #{reason}"
      )
    ]
  end

  def manual_grant_dm(request, admin_name) do
    [
      section("*Manual provisioning needed*"),
      fields([
        {"User", request.affected_user.full_name},
        {"Application", request.application.name},
        {"Assigned to", admin_name}
      ]),
      actions([
        button("Grant Access", "manual_grant:#{request.id}", "primary"),
        button("Reject", "manual_reject:#{request.id}", "danger")
      ])
    ]
  end

  def request_modal(applications) do
    %{
      type: "modal",
      callback_id: "submit_request",
      title: %{type: "plain_text", text: "Request Access"},
      submit: %{type: "plain_text", text: "Submit"},
      blocks: [
        %{
          type: "input",
          block_id: "app_block",
          element: %{
            type: "static_select",
            action_id: "application_id",
            placeholder: %{type: "plain_text", text: "Select an application"},
            options:
              Enum.map(applications, fn app ->
                label = if app.live_integration, do: "#{app.name} ✦ live", else: app.name
                %{text: %{type: "plain_text", text: label}, value: app.id}
              end)
          },
          label: %{type: "plain_text", text: "Application"}
        },
        %{
          type: "input",
          block_id: "reason_block",
          element: %{type: "plain_text_input", action_id: "reason", multiline: true},
          label: %{type: "plain_text", text: "Why do you need access?"}
        }
      ]
    }
  end

  def approved_update(approver_name) do
    [section("✅ *Approved* by #{approver_name}. Provisioning in progress...")]
  end

  def denied_update(denier_name, reason) do
    [section("❌ *Denied* by #{denier_name}. Reason: #{reason}")]
  end

  defp section(text) do
    %{type: "section", text: %{type: "mrkdwn", text: text}}
  end

  defp fields(pairs) do
    %{
      type: "section",
      fields:
        Enum.flat_map(pairs, fn {label, value} ->
          [
            %{type: "mrkdwn", text: "*#{label}*"},
            %{type: "mrkdwn", text: value || "-"}
          ]
        end)
    }
  end

  defp actions(buttons) do
    %{type: "actions", elements: buttons}
  end

  defp button(text, action_id, style) do
    %{
      type: "button",
      text: %{type: "plain_text", text: text},
      action_id: action_id,
      style: style
    }
  end
end
