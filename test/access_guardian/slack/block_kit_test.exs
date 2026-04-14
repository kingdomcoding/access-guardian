defmodule AccessGuardian.Slack.BlockKitTest do
  use ExUnit.Case

  alias AccessGuardian.Slack.BlockKit

  defp mock_request do
    %{
      id: "req-123",
      affected_user: %{full_name: "David Kim"},
      application: %{name: "GitHub"},
      request_reason: "Need repo access",
      reject_reason: nil
    }
  end

  test "approval_request_dm contains approve and deny buttons" do
    blocks = BlockKit.approval_request_dm(mock_request())

    action_block = Enum.find(blocks, &(&1.type == "actions"))
    assert action_block

    action_ids = Enum.map(action_block.elements, & &1.action_id)
    assert "approve_request:req-123" in action_ids
    assert "deny_request:req-123" in action_ids
  end

  test "approval_request_dm contains requester and app name" do
    blocks = BlockKit.approval_request_dm(mock_request())

    text =
      blocks
      |> Enum.flat_map(fn
        %{fields: fields} when is_list(fields) -> Enum.map(fields, & &1.text)
        %{text: %{text: t}} -> [t]
        _ -> []
      end)
      |> Enum.join(" ")

    assert text =~ "David Kim"
    assert text =~ "GitHub"
  end

  test "provisioning_result_dm granted shows success" do
    blocks = BlockKit.provisioning_result_dm(mock_request(), :granted)
    text = hd(blocks).text.text
    assert text =~ "Access granted"
    assert text =~ "GitHub"
  end

  test "provisioning_result_dm rejected shows failure with reason" do
    request = %{mock_request() | reject_reason: "UI changed"}
    blocks = BlockKit.provisioning_result_dm(request, :rejected)
    text = hd(blocks).text.text
    assert text =~ "could not be provisioned"
    assert text =~ "UI changed"
  end

  test "request_modal contains app dropdown and reason input" do
    apps = [%{id: "app-1", name: "GitHub"}, %{id: "app-2", name: "Slack"}]
    modal = BlockKit.request_modal(apps)

    assert modal.type == "modal"
    assert modal.callback_id == "submit_request"
    assert length(modal.blocks) == 2

    app_block = Enum.at(modal.blocks, 0)
    assert app_block.block_id == "app_block"
    assert length(app_block.element.options) == 2

    reason_block = Enum.at(modal.blocks, 1)
    assert reason_block.block_id == "reason_block"
  end
end
