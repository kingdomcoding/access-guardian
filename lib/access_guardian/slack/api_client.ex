defmodule AccessGuardian.Slack.ApiClient do
  @behaviour AccessGuardian.Slack.ApiBehaviour

  defp token, do: System.get_env("SLACK_BOT_TOKEN") || ""

  defp client do
    Req.new(
      base_url: "https://slack.com/api",
      headers: [{"authorization", "Bearer #{token()}"}]
    )
  end

  @impl true
  def post_message(channel, blocks, opts \\ []) do
    body = %{channel: channel, blocks: blocks}
    body = if opts[:text], do: Map.put(body, :text, opts[:text]), else: body
    Req.post(client(), url: "/chat.postMessage", json: body)
    :ok
  end

  @impl true
  def open_modal(trigger_id, view) do
    Req.post(client(), url: "/views.open", json: %{trigger_id: trigger_id, view: view})
    :ok
  end

  @impl true
  def update_message(channel, ts, blocks) do
    Req.post(client(), url: "/chat.update", json: %{channel: channel, ts: ts, blocks: blocks})
    :ok
  end

  @impl true
  def get_user_info(user_id) do
    case Req.get(client(), url: "/users.info", params: [user: user_id]) do
      {:ok, %{status: 200, body: %{"ok" => true, "user" => user}}} ->
        {:ok,
         %{
           email: get_in(user, ["profile", "email"]),
           real_name: get_in(user, ["profile", "real_name"]) || user["real_name"] || "Slack User",
           display_name: get_in(user, ["profile", "display_name"])
         }}

      {:ok, %{body: %{"error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
