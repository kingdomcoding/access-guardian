defmodule AccessGuardianWeb.DashboardLive do
  use AccessGuardianWeb, :live_view
  import AccessGuardianWeb.StatusHelpers

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      AccessGuardianWeb.Endpoint.subscribe("access_requests:created")
      AccessGuardianWeb.Endpoint.subscribe("access_requests:updated")
    end

    {:ok, load_data(socket)}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_info(%{topic: "access_requests:" <> _}, socket) do
    {:noreply, load_data(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp load_data(socket) do
    org = get_org()
    {:ok, requests} = AccessGuardian.Access.list_by_org(org.id)

    stats = %{
      total: length(requests),
      pending: Enum.count(requests, &(&1.status == :pending_approval)),
      granted: Enum.count(requests, &(&1.status == :granted)),
      needs_attention:
        Enum.count(requests, fn r ->
          r.status == :pending_approval or r.pending_manual
        end)
    }

    assign(socket,
      page_title: "Dashboard",
      stats: stats,
      recent: Enum.take(requests, 10)
    )
  end

  defp get_org do
    {:ok, [org | _]} = Ash.read(AccessGuardian.Catalog.Organization)
    org
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-bold text-gray-900">AccessGuardian Dashboard</h1>
        <.link navigate="/requests" class="text-sm text-blue-600 hover:underline">
          View all requests →
        </.link>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <div class="bg-white rounded-xl border border-gray-200 p-5">
          <p class="text-sm font-medium text-gray-500">Pipeline</p>
          <p class="text-2xl font-bold text-gray-900 mt-1">{@stats.total}</p>
          <p class="text-xs text-gray-500 mt-1">{@stats.pending} pending approval</p>
        </div>
        <div class="bg-white rounded-xl border border-gray-200 p-5">
          <p class="text-sm font-medium text-gray-500">Granted</p>
          <p class="text-2xl font-bold text-green-600 mt-1">{@stats.granted}</p>
        </div>
        <div class={"bg-white rounded-xl border p-5 " <> if(@stats.needs_attention > 0, do: "border-orange-200", else: "border-gray-200")}>
          <p class="text-sm font-medium text-gray-500">Needs Attention</p>
          <p class="text-2xl font-bold text-gray-900 mt-1">{@stats.needs_attention}</p>
        </div>
      </div>

      <div class="bg-white rounded-xl border border-gray-200 p-5">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-sm font-semibold text-gray-900">Recent Requests</h2>
          <.link navigate="/requests" class="text-xs text-blue-600 hover:underline">View all →</.link>
        </div>
        <div class="divide-y divide-gray-100">
          <.link
            :for={req <- @recent}
            navigate={"/requests?selected=#{req.id}"}
            class="flex items-center justify-between py-3 hover:bg-gray-50 -mx-2 px-2 rounded-lg"
          >
            <div class="flex items-center gap-3 min-w-0">
              <span class="text-sm text-gray-900 truncate">{req.affected_user.full_name}</span>
              <span class="text-xs text-gray-500">{req.application.name}</span>
            </div>
            <div class="flex items-center gap-2">
              <.status_badge status={req.status} pending_manual={req.pending_manual} />
              <span class="text-xs text-gray-400 hidden sm:inline">{time_ago(req.inserted_at)}</span>
            </div>
          </.link>
          <p :if={@recent == []} class="py-8 text-center text-sm text-gray-500">
            No requests yet.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
