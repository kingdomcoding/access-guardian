defmodule AccessGuardianWeb.Plugs.SlackSignatureTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias AccessGuardianWeb.Plugs.SlackSignature

  @secret "test-signing-secret"

  setup do
    System.put_env("SLACK_SIGNING_SECRET", @secret)
    Application.put_env(:access_guardian, :slack_enabled, true)

    on_exit(fn ->
      System.delete_env("SLACK_SIGNING_SECRET")
      Application.put_env(:access_guardian, :slack_enabled, false)
    end)

    :ok
  end

  defp sign(body, timestamp) do
    base = "v0:#{timestamp}:#{body}"
    "v0=" <> (:crypto.mac(:hmac, :sha256, @secret, base) |> Base.encode16(case: :lower))
  end

  test "valid signature passes" do
    body = "payload=test"
    ts = to_string(System.system_time(:second))
    sig = sign(body, ts)

    conn =
      conn(:post, "/api/slack/commands", body)
      |> assign(:raw_body, body)
      |> put_req_header("x-slack-request-timestamp", ts)
      |> put_req_header("x-slack-signature", sig)
      |> SlackSignature.call(SlackSignature.init([]))

    refute conn.halted
  end

  test "tampered body returns 401" do
    body = "payload=test"
    ts = to_string(System.system_time(:second))
    sig = sign(body, ts)

    conn =
      conn(:post, "/api/slack/commands", "payload=tampered")
      |> assign(:raw_body, "payload=tampered")
      |> put_req_header("x-slack-request-timestamp", ts)
      |> put_req_header("x-slack-signature", sig)
      |> SlackSignature.call(SlackSignature.init([]))

    assert conn.halted
    assert conn.status == 401
  end

  test "expired timestamp returns 401" do
    body = "payload=test"
    ts = to_string(System.system_time(:second) - 600)
    sig = sign(body, ts)

    conn =
      conn(:post, "/api/slack/commands", body)
      |> assign(:raw_body, body)
      |> put_req_header("x-slack-request-timestamp", ts)
      |> put_req_header("x-slack-signature", sig)
      |> SlackSignature.call(SlackSignature.init([]))

    assert conn.halted
    assert conn.status == 401
  end

  test "returns 503 when slack not configured" do
    Application.put_env(:access_guardian, :slack_enabled, false)

    conn =
      conn(:post, "/api/slack/commands", "")
      |> SlackSignature.call(SlackSignature.init([]))

    assert conn.halted
    assert conn.status == 503
  end
end
