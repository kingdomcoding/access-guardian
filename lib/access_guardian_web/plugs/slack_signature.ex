defmodule AccessGuardianWeb.Plugs.SlackSignature do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if not Application.get_env(:access_guardian, :slack_enabled, false) do
      conn |> send_resp(503, "Slack not configured") |> halt()
    else
      verify_signature(conn)
    end
  end

  defp verify_signature(conn) do
    signing_secret = System.get_env("SLACK_SIGNING_SECRET") || ""
    timestamp = List.first(get_req_header(conn, "x-slack-request-timestamp")) || "0"
    signature = List.first(get_req_header(conn, "x-slack-signature")) || ""
    raw_body = conn.assigns[:raw_body] || ""

    base = "v0:#{timestamp}:#{raw_body}"

    expected =
      "v0=" <>
        (:crypto.mac(:hmac, :sha256, signing_secret, base) |> Base.encode16(case: :lower))

    now = System.system_time(:second)
    ts = String.to_integer(timestamp)

    cond do
      abs(now - ts) > 300 ->
        conn |> send_resp(401, "Timestamp expired") |> halt()

      not Plug.Crypto.secure_compare(expected, signature) ->
        conn |> send_resp(401, "Invalid signature") |> halt()

      true ->
        conn
    end
  rescue
    _ -> conn |> send_resp(401, "Signature verification failed") |> halt()
  end
end
