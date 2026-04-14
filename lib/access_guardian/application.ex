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
      {Oban, Application.fetch_env!(:access_guardian, Oban)},
      {Task.Supervisor, name: AccessGuardian.SlackTaskSupervisor},
      AccessGuardian.Slack.Listener,
      AccessGuardianWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AccessGuardian.Supervisor]
    result = Supervisor.start_link(children, opts)

    maybe_seed()

    result
  end

  defp maybe_seed do
    case Ash.read(AccessGuardian.Catalog.Organization) do
      {:ok, []} ->
        seeds_path = Application.app_dir(:access_guardian, "priv/repo/seeds.exs")

        if File.exists?(seeds_path) do
          Code.eval_file(seeds_path)
        end

      _ ->
        :ok
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
