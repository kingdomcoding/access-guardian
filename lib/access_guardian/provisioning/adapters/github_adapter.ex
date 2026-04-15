defmodule AccessGuardian.Provisioning.Adapters.GithubAdapter do
  @behaviour AccessGuardian.Provisioning.Adapter
  require Logger

  @impl true
  def provision(app, user, _entitlements) do
    token = System.get_env("GITHUB_TOKEN")
    org = app.config["github_org"] || System.get_env("GITHUB_ORG")
    email = to_string(user.email)

    Logger.info("[GithubAdapter] Inviting #{email} to org #{org}")

    case invite_by_email(token, org, email) do
      {:ok, invitation} ->
        invitation_id = invitation["id"] || email
        {:ok, %{external_account_id: "github-invite:#{invitation_id}"}}

      error ->
        error
    end
  end

  @impl true
  def deprovision(app, user) do
    token = System.get_env("GITHUB_TOKEN")
    org = app.config["github_org"] || System.get_env("GITHUB_ORG")
    email = to_string(user.email)

    Logger.info("[GithubAdapter] Removing #{email} from org #{org}")

    case find_member_by_email(token, org, email) do
      {:ok, username} ->
        case Req.delete(client(token), url: "/orgs/#{org}/members/#{username}") do
          {:ok, %{status: status}} when status in [204, 404] -> :ok
          {:ok, %{status: status}} -> {:error, :transient, "GitHub API returned #{status}"}
          {:error, reason} -> {:error, :transient, "Network error: #{inspect(reason)}"}
        end

      {:error, :not_found} ->
        :ok
    end
  end

  defp invite_by_email(token, org, email) do
    Logger.info("[GithubAdapter] POST /orgs/#{org}/invitations (email: #{email})")

    case Req.post(client(token),
           url: "/orgs/#{org}/invitations",
           json: %{email: email, role: "direct_member"}
         ) do
      {:ok, %{status: 201, body: body}} ->
        Logger.info("[GithubAdapter] Invitation created for #{email}")
        {:ok, body}

      {:ok, %{status: 422, body: body}} ->
        full_text = inspect(body)

        if String.contains?(full_text, "already") do
          Logger.info("[GithubAdapter] #{email} already invited/member — treating as success")
          {:ok, %{"id" => email}}
        else
          msg = if is_map(body), do: body["message"], else: full_text
          Logger.error("[GithubAdapter] 422: #{full_text}")
          {:error, :permanent, "GitHub 422: #{msg}"}
        end

      {:ok, %{status: 404}} ->
        {:error, :permanent, "GitHub org #{org} not found"}

      {:ok, %{status: 403, body: body}} ->
        msg = if is_map(body), do: body["message"], else: inspect(body)
        Logger.error("[GithubAdapter] 403: #{msg}")
        {:error, :permanent, "GitHub 403: #{msg}"}

      {:ok, %{status: 429}} ->
        {:error, :transient, "GitHub rate limit exceeded"}

      {:ok, %{status: status, body: body}} ->
        msg = if is_map(body), do: body["message"], else: inspect(body)
        {:error, :transient, "GitHub API error #{status}: #{msg}"}

      {:error, reason} ->
        {:error, :transient, "Network error: #{inspect(reason)}"}
    end
  end

  defp find_member_by_email(token, org, email) do
    case Req.get(client(token), url: "/orgs/#{org}/members") do
      {:ok, %{status: 200, body: members}} when is_list(members) ->
        case Enum.find(members, fn m -> m["email"] == email end) do
          nil -> {:error, :not_found}
          member -> {:ok, member["login"]}
        end

      _ ->
        {:error, :not_found}
    end
  end

  defp client(token) do
    Req.new(
      base_url: "https://api.github.com",
      headers: [
        {"authorization", "Bearer #{token}"},
        {"accept", "application/vnd.github+json"},
        {"x-github-api-version", "2022-11-28"}
      ]
    )
  end
end
