defmodule AccessGuardian.Slack.EnsureUser do
  require Logger
  require Ash.Query

  defp api_client, do: Application.get_env(:access_guardian, :slack_api_module)

  def call(slack_user_id) do
    case AccessGuardian.Catalog.get_user_by_slack_id(slack_user_id) do
      {:ok, user} ->
        user

      _ ->
        create_or_link_from_slack(slack_user_id)
    end
  end

  defp create_or_link_from_slack(slack_user_id) do
    Logger.info("[Slack] Looking up Slack user #{slack_user_id}")

    case api_client().get_user_info(slack_user_id) do
      {:ok, info} ->
        Logger.info("[Slack] Got user info: #{inspect(info)}")
        org = get_default_org()
        email = info.email || "slack-#{slack_user_id}@placeholder.local"

        case find_by_email(org.id, email) do
          nil ->
            create_new_user(org.id, slack_user_id, email, info)

          existing ->
            link_slack_id(existing, slack_user_id)
        end

      {:error, reason} ->
        Logger.error("[Slack] Failed to fetch user info for #{slack_user_id}: #{inspect(reason)}")
        nil
    end
  rescue
    e ->
      Logger.error("[Slack] Exception in create_or_link: #{inspect(e)}")
      nil
  end

  defp find_by_email(org_id, email) do
    AccessGuardian.Catalog.User
    |> Ash.Query.filter(organization_id == ^org_id and email == ^email)
    |> Ash.read_one!()
  rescue
    _ -> nil
  end

  defp create_new_user(org_id, slack_user_id, email, info) do
    {:ok, user} =
      AccessGuardian.Catalog.create_user(%{
        organization_id: org_id,
        slack_user_id: slack_user_id,
        email: email,
        full_name: info.real_name || "Slack User",
        org_role: :user
      })

    Logger.info("[Slack] Created user #{user.full_name} (#{user.email})")
    user
  end

  defp link_slack_id(user, slack_user_id) do
    {:ok, updated} =
      user
      |> Ash.Changeset.for_update(:update, %{slack_user_id: slack_user_id})
      |> Ash.update()

    Logger.info("[Slack] Linked Slack ID #{slack_user_id} to existing user #{updated.full_name}")
    updated
  end

  defp get_default_org do
    {:ok, [org | _]} = Ash.read(AccessGuardian.Catalog.Organization)
    org
  end
end
