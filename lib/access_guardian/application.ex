defmodule AccessGuardian.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AccessGuardianWeb.Telemetry,
      AccessGuardian.Repo,
      {DNSCluster, query: Application.get_env(:access_guardian, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AccessGuardian.PubSub},
      {Finch, name: AccessGuardian.Finch},
      {Oban, Application.fetch_env!(:access_guardian, Oban)},
      {Task.Supervisor, name: AccessGuardian.SlackTaskSupervisor},
      AccessGuardianWeb.Endpoint,
      AccessGuardian.Slack.Listener
    ]

    opts = [strategy: :one_for_one, name: AccessGuardian.Supervisor]
    result = Supervisor.start_link(children, opts)

    maybe_seed()

    result
  end

  defp maybe_seed do
    if Application.get_env(:access_guardian, :skip_seed, false) do
      :ok
    else
      case Ash.read(AccessGuardian.Catalog.Organization) do
        {:ok, []} ->
          seeds_path = Application.app_dir(:access_guardian, "priv/repo/seeds.exs")

          if File.exists?(seeds_path) do
            Code.eval_file(seeds_path)
          end

        _ ->
          :ok
      end
    end
  rescue
    _ -> :ok
  end

  @impl true
  def config_change(changed, _new, removed) do
    AccessGuardianWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
