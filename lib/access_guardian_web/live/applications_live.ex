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
        <h1 class="text-xl font-bold text-gray-900">Applications</h1>
        <.link navigate="/" class="text-sm text-gray-500 hover:text-gray-700">← Dashboard</.link>
      </div>

      <div class="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100">
        <div :for={app <- @applications} class="px-4 py-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-900">{app.name}</p>
              <p class="text-xs text-gray-500 mt-0.5">
                Owner: {if app.business_owner, do: app.business_owner.full_name, else: "—"} · {length(
                  app.admin_assignments
                )} admin(s)
              </p>
            </div>
            <span class={[
              "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
              integration_badge_class(app.integration_type)
            ]}>
              {app.integration_type}
            </span>
          </div>
        </div>
        <div :if={@applications == []} class="px-4 py-8 text-center text-sm text-gray-500">
          No applications configured.
        </div>
      </div>
    </div>
    """
  end

  defp integration_badge_class(:api), do: "bg-blue-100 text-blue-800"
  defp integration_badge_class(:agentic), do: "bg-purple-100 text-purple-800"
  defp integration_badge_class(:scim), do: "bg-indigo-100 text-indigo-800"
  defp integration_badge_class(:manual), do: "bg-gray-100 text-gray-800"
  defp integration_badge_class(_), do: "bg-gray-100 text-gray-800"
end
