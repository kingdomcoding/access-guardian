defmodule AccessGuardian.Provisioning.Adapters.GithubAdapter do
  @behaviour AccessGuardian.Provisioning.Adapter
  require Logger

  @impl true
  def provision(app, user, _entitlements) do
    token = System.get_env("GITHUB_TOKEN")
    org = app.config["github_org"] || System.get_env("GITHUB_ORG")
    team = app.config["github_team"]
    username = derive_username(user)

    Logger.info("[GithubAdapter] Provisioning #{username} to org #{org}")

    with {:ok, membership} <- invite_to_org(token, org, username),
         :ok <- maybe_add_to_team(token, org, team, username) do
      user_id = get_in(membership, ["user", "id"]) || username
      {:ok, %{external_account_id: "github:#{user_id}"}}
    end
  end

  @impl true
  def deprovision(app, user) do
    token = System.get_env("GITHUB_TOKEN")
    org = app.config["github_org"] || System.get_env("GITHUB_ORG")
    username = derive_username(user)

    Logger.info("[GithubAdapter] Removing #{username} from org #{org}")

    case Req.delete(client(token), url: "/orgs/#{org}/members/#{username}") do
      {:ok, %{status: status}} when status in [204, 404] -> :ok
      {:ok, %{status: 403}} -> {:error, :permanent, "Insufficient permissions"}
      {:ok, %{status: status}} -> {:error, :transient, "GitHub API returned #{status}"}
      {:error, reason} -> {:error, :transient, "Network error: #{inspect(reason)}"}
    end
  end

  defp invite_to_org(token, org, username) do
    Logger.info("[GithubAdapter] PUT /orgs/#{org}/memberships/#{username}")

    case Req.put(client(token),
           url: "/orgs/#{org}/memberships/#{username}",
           json: %{role: "member"}
         ) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("[GithubAdapter] Invited #{username} — state: #{body["state"]}")
        {:ok, body}

      {:ok, %{status: 422}} ->
        Logger.info("[GithubAdapter] #{username} already in org — treating as success")
        {:ok, %{"user" => %{"id" => username}}}

      {:ok, %{status: 404}} ->
        {:error, :permanent, "GitHub user #{username} not found"}

      {:ok, %{status: 403}} ->
        {:error, :permanent, "Insufficient permissions — check token scopes (needs admin:org)"}

      {:ok, %{status: 429}} ->
        {:error, :transient, "GitHub rate limit exceeded"}

      {:ok, %{status: status, body: body}} ->
        msg = if is_map(body), do: body["message"], else: inspect(body)
        {:error, :transient, "GitHub API error #{status}: #{msg}"}

      {:error, reason} ->
        {:error, :transient, "Network error: #{inspect(reason)}"}
    end
  end

  defp maybe_add_to_team(_token, _org, nil, _username), do: :ok
  defp maybe_add_to_team(_token, _org, "", _username), do: :ok

  defp maybe_add_to_team(token, org, team_slug, username) do
    Logger.info("[GithubAdapter] PUT /orgs/#{org}/teams/#{team_slug}/memberships/#{username}")

    case Req.put(client(token),
           url: "/orgs/#{org}/teams/#{team_slug}/memberships/#{username}",
           json: %{role: "member"}
         ) do
      {:ok, %{status: status}} when status in [200, 422] -> :ok
      {:ok, %{status: 404}} -> {:error, :permanent, "Team #{team_slug} not found"}
      {:ok, %{status: 429}} -> {:error, :transient, "GitHub rate limit exceeded"}
      {:ok, %{status: status}} -> {:error, :transient, "GitHub team API error #{status}"}
      {:error, reason} -> {:error, :transient, "Network error: #{inspect(reason)}"}
    end
  end

  defp derive_username(user) do
    user.email |> to_string() |> String.split("@") |> hd()
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
