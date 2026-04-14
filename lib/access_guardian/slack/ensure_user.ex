defmodule AccessGuardian.Slack.EnsureUser do
  require Logger

  defp api_client, do: Application.get_env(:access_guardian, :slack_api_module)

  def call(slack_user_id) do
    case AccessGuardian.Catalog.get_user_by_slack_id(slack_user_id) do
      {:ok, user} ->
        user

      _ ->
        create_from_slack(slack_user_id)
    end
  end

  defp create_from_slack(slack_user_id) do
    case api_client().get_user_info(slack_user_id) do
      {:ok, info} ->
        org = get_default_org()

        {:ok, user} =
          AccessGuardian.Catalog.create_user(%{
            organization_id: org.id,
            slack_user_id: slack_user_id,
            email: info.email || "slack-#{slack_user_id}@placeholder.local",
            full_name: info.real_name || "Slack User",
            org_role: :user
          })

        Logger.info("[Slack] Auto-created user #{user.full_name} (#{user.email}) from Slack ID #{slack_user_id}")
        user

      {:error, reason} ->
        Logger.error("[Slack] Failed to fetch user info for #{slack_user_id}: #{inspect(reason)}")
        nil
    end
  end

  defp get_default_org do
    {:ok, [org | _]} = Ash.read(AccessGuardian.Catalog.Organization)
    org
  end
end
