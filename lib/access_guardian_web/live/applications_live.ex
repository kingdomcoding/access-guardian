defmodule AccessGuardianWeb.ApplicationsLive do
  use AccessGuardianWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    org = get_org()
    {:ok, apps} = AccessGuardian.Catalog.list_applications_by_org(org.id)

    apps =
      Enum.map(apps, fn app ->
        {:ok, app} = Ash.load(app, [:business_owner, :admin_assignments])
        app
      end)

    {:ok, assign(socket, page_title: "Applications", applications: apps)}
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
        <.link navigate="/" class="text-sm link link-hover text-base-content/60">← Dashboard</.link>
      </div>

      <div class="bg-base-100 rounded-xl border border-base-300 divide-y divide-base-200">
        <div :for={app <- @applications} class="px-4 py-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-base-content">{app.name}</p>
              <p class="text-xs text-base-content/50 mt-0.5">
                Owner: {if app.business_owner, do: app.business_owner.full_name, else: "—"} · {length(
                  app.admin_assignments
                )} admin(s)
              </p>
            </div>
            <span class={["badge badge-sm", integration_badge_class(app.integration_type)]}>
              {app.integration_type}
            </span>
          </div>
        </div>
        <div :if={@applications == []} class="px-4 py-8 text-center text-sm text-base-content/50">
          No applications configured.
        </div>
      </div>
    </div>
    """
  end

  defp integration_badge_class(:api), do: "badge-info"
  defp integration_badge_class(:agentic), do: "badge-secondary"
  defp integration_badge_class(:scim), do: "badge-primary"
  defp integration_badge_class(:manual), do: "badge-ghost"
  defp integration_badge_class(_), do: "badge-ghost"
end
