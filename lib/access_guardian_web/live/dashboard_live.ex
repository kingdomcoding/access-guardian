defmodule AccessGuardianWeb.DashboardLive do
  use AccessGuardianWeb, :live_view
  import AccessGuardianWeb.StatusHelpers

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      AccessGuardianWeb.Endpoint.subscribe("access_requests:created")
      AccessGuardianWeb.Endpoint.subscribe("access_requests:updated")
    end

    org = get_org()
    {:ok, requests} = AccessGuardian.Access.list_by_org(org.id)
    {:ok, apps} = AccessGuardian.Catalog.list_applications_by_org(org.id)
    {:ok, users} = AccessGuardian.Catalog.list_users_by_org(org.id)

    gitlab_session =
      case Ash.read(AccessGuardian.Catalog.IntegrationSession) do
        {:ok, sessions} ->
          Enum.find(sessions, &(&1.platform == :gitlab and &1.status == :active))

        _ ->
          nil
      end

    github_configured =
      System.get_env("GITHUB_TOKEN") not in [nil, ""] and
        System.get_env("GITHUB_ORG") not in [nil, ""]

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       org: org,
       recent: Enum.take(requests, 5),
       apps: apps,
       users: users,
       github_configured: github_configured,
       github_org: System.get_env("GITHUB_ORG"),
       gitlab_session: gitlab_session,
       gitlab_group_path: System.get_env("GITLAB_GROUP_PATH")
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_info(%{topic: "access_requests:" <> _}, socket) do
    {:ok, requests} = AccessGuardian.Access.list_by_org(socket.assigns.org.id)
    {:noreply, assign(socket, recent: Enum.take(requests, 5))}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("create_request", params, socket) do
    attrs = %{
      organization_id: socket.assigns.org.id,
      affected_user_id: params["user_id"],
      requested_by_id: params["user_id"],
      application_id: params["application_id"],
      request_reason: params["reason"]
    }

    case AccessGuardian.Access.create_request(attrs) do
      {:ok, request} ->
        {:noreply,
         socket
         |> put_flash(:info, "Request created!")
         |> push_navigate(to: "/requests?selected=#{request.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create request.")}
    end
  end

  defp get_org do
    {:ok, [org | _]} = Ash.read(AccessGuardian.Catalog.Organization)
    org
  end

  defp app_label(%{live_integration: true, integration_type: :api} = app),
    do: "#{app.name} ⚡ API"

  defp app_label(%{live_integration: true, integration_type: :agentic} = app),
    do: "#{app.name} ⚡ Playwright"

  defp app_label(app), do: app.name

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-base-content">AccessGuardian</h1>
        <p class="text-sm text-base-content/60 mt-1">
          Mirrors AccessOwl's core workflow — access request, approval, and provisioning — with real integrations.
        </p>
        <div class="flex flex-wrap gap-2 mt-3">
          <span class="badge badge-sm badge-outline">Ash Framework</span>
          <span class="badge badge-sm badge-outline badge-info">GitHub API</span>
          <span class="badge badge-sm badge-outline badge-secondary">GitLab Playwright</span>
          <span class="badge badge-sm badge-outline badge-accent">Slack Bot</span>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
        <div class="bg-base-100 rounded-xl border border-base-300 p-4">
          <div class="flex items-center gap-2 mb-2">
            <span class={[
              "w-2.5 h-2.5 rounded-full",
              if(@github_configured, do: "bg-success", else: "bg-base-300")
            ]} />
            <span class="text-sm font-semibold text-base-content">GitHub</span>
            <span class="badge badge-xs badge-info">API</span>
          </div>
          <div :if={@github_configured} class="text-xs text-base-content/60">
            Org: <span class="font-medium text-base-content">{@github_org}</span> · Ready
          </div>
          <div :if={!@github_configured} class="text-xs text-base-content/40">
            Not configured
          </div>
        </div>

        <div class="bg-base-100 rounded-xl border border-base-300 p-4">
          <div class="flex items-center gap-2 mb-2">
            <span class={[
              "w-2.5 h-2.5 rounded-full",
              cond do
                @gitlab_session -> "bg-success"
                @gitlab_group_path -> "bg-warning"
                true -> "bg-base-300"
              end
            ]} />
            <span class="text-sm font-semibold text-base-content">GitLab</span>
            <span class="badge badge-xs badge-secondary">Playwright</span>
          </div>
          <div :if={@gitlab_session} class="text-xs text-base-content/60">
            Group: <span class="font-medium text-base-content">{@gitlab_group_path}</span>
            · Session active
          </div>
          <div :if={!@gitlab_session && @gitlab_group_path} class="text-xs text-base-content/40">
            No active session ·
            <.link navigate="/integrations/setup" class="link link-primary">Set up</.link>
          </div>
          <div :if={!@gitlab_session && !@gitlab_group_path} class="text-xs text-base-content/40">
            Not configured
          </div>
        </div>
      </div>

      <div class="bg-base-100 rounded-xl border border-base-300 p-5 mb-8">
        <h2 class="text-sm font-semibold text-base-content mb-3">Try the Pipeline</h2>
        <form phx-submit="create_request" class="flex flex-wrap gap-3 items-end">
          <div class="flex-1 min-w-[140px]">
            <label class="label text-xs">Application</label>
            <select
              name="application_id"
              class="select select-bordered select-sm w-full"
              required
            >
              <option value="" disabled selected>Pick an app</option>
              {Phoenix.HTML.Form.options_for_select(
                Enum.map(@apps, fn app -> {app_label(app), app.id} end),
                nil
              )}
            </select>
          </div>
          <div class="flex-1 min-w-[140px]">
            <label class="label text-xs">User</label>
            <select name="user_id" class="select select-bordered select-sm w-full" required>
              <option value="" disabled selected>Pick a user</option>
              {Phoenix.HTML.Form.options_for_select(
                Enum.map(@users, fn u -> {u.full_name, u.id} end),
                nil
              )}
            </select>
          </div>
          <div class="flex-1 min-w-[200px]">
            <label class="label text-xs">Reason</label>
            <input
              type="text"
              name="reason"
              value="Demo access request"
              class="input input-bordered input-sm w-full"
            />
          </div>
          <button type="submit" class="btn btn-primary btn-sm">Create Request</button>
        </form>
        <p class="text-xs text-base-content/40 mt-3">
          Or try via Slack —
          <a
            href="https://join.slack.com/t/access-guardian-demo/shared_invite/zt-3v3fpne7b-d_eXEtT6IBOeGtpWe_QjJw"
            target="_blank"
            class="link"
          >
            join access-guardian-demo.slack.com
          </a>
          and type <code class="text-base-content/60">/request</code>
        </p>
      </div>

      <div class="bg-base-100 rounded-xl border border-base-300 p-5">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-base-content">Recent Activity</h2>
          <.link navigate="/requests" class="text-xs link link-primary">View all &rarr;</.link>
        </div>
        <div class="text-xs text-base-content/40 flex items-center justify-between px-2 mb-1">
          <span>Requester · Application</span>
          <span>Status · When</span>
        </div>
        <div class="divide-y divide-base-200">
          <.link
            :for={req <- @recent}
            navigate={"/requests?selected=#{req.id}"}
            class="flex items-center justify-between py-2.5 hover:bg-base-200 -mx-2 px-2 rounded-lg"
          >
            <div class="flex items-center gap-2 min-w-0">
              <span class="text-sm text-base-content truncate">
                {req.affected_user.full_name}
              </span>
              <span class="text-xs text-base-content/50">{req.application.name}</span>
            </div>
            <div class="flex items-center gap-2">
              <.status_badge status={req.status} pending_manual={req.pending_manual} />
              <span
                class="text-xs text-base-content/40 hidden sm:inline"
                title={DateTime.to_string(req.inserted_at)}
              >
                {time_ago(req.inserted_at)}
              </span>
            </div>
          </.link>
          <p :if={@recent == []} class="py-6 text-center text-sm text-base-content/50">
            No requests yet. Create one above to see the pipeline in action.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
