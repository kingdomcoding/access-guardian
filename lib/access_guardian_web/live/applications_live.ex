defmodule AccessGuardianWeb.ApplicationsLive do
  use AccessGuardianWeb, :live_view

  @integration_groups [
    {:api, "API Integrations", "REST API-based provisioning"},
    {:agentic, "Agentic Integrations", "Browser automation via Playwright"},
    {:scim, "SCIM Integrations", "Standard SCIM protocol"},
    {:manual, "Manual Integrations", "Human-assisted provisioning"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    org = get_org()
    {:ok, apps} = AccessGuardian.Catalog.list_applications_by_org(org.id)

    apps =
      Enum.map(apps, fn app ->
        {:ok, app} = Ash.load(app, [:business_owner, :admin_assignments])
        app
      end)

    grouped = Enum.group_by(apps, & &1.integration_type)

    {:ok,
     assign(socket,
       page_title: "Applications",
       grouped: grouped,
       groups: @integration_groups
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  defp get_org do
    {:ok, [org | _]} = Ash.read(AccessGuardian.Catalog.Organization)
    org
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-bold text-base-content">Applications</h1>
        <div class="flex items-center gap-3">
          <.link navigate="/integrations/setup" class="btn btn-sm btn-outline">
            GitLab Session Setup
          </.link>
          <.link navigate="/" class="text-sm link link-hover text-base-content/60">
            &larr; Dashboard
          </.link>
        </div>
      </div>

      <div :for={{type, title, desc} <- @groups} :if={Map.has_key?(@grouped, type)} class="mb-6">
        <div class="flex items-center gap-2 mb-2">
          <h2 class="text-sm font-semibold text-base-content">{title}</h2>
          <span class="badge badge-xs badge-ghost">{length(@grouped[type])}</span>
        </div>
        <p class="text-xs text-base-content/40 mb-2">{desc}</p>
        <div class="bg-base-100 rounded-xl border border-base-300 divide-y divide-base-200">
          <div :for={app <- @grouped[type]} class="px-4 py-3">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-base-content">{app.name}</p>
                <p class="text-xs text-base-content/50 mt-0.5">
                  Owner: {if app.business_owner, do: app.business_owner.full_name, else: "—"} · {length(app.admin_assignments)} admin(s)
                </p>
              </div>
              <div class="flex items-center gap-1.5">
                <span
                  :if={app.live_integration and app.integration_type == :api}
                  class="badge badge-sm badge-success"
                >
                  API
                </span>
                <span
                  :if={app.live_integration and app.integration_type == :agentic}
                  class="badge badge-sm badge-success"
                >
                  PLAYWRIGHT
                </span>
                <span :if={not app.live_integration} class="badge badge-sm badge-ghost">MOCK</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
