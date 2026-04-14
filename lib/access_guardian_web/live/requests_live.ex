defmodule AccessGuardianWeb.RequestsLive do
  use AccessGuardianWeb, :live_view
  import AccessGuardianWeb.StatusHelpers
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      AccessGuardianWeb.Endpoint.subscribe("access_requests:created")
      AccessGuardianWeb.Endpoint.subscribe("access_requests:updated")
    end

    {:ok, assign(socket, page_title: "Access Requests")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    org = get_org()
    filter = params["filter"]
    search = params["search"]
    selected_id = params["selected"]

    requests = load_requests(org.id, filter, search)
    selected = if selected_id, do: load_request(selected_id)

    {:noreply,
     assign(socket,
       org: org,
       requests: requests,
       selected: selected,
       filter: filter,
       search: search || ""
     )}
  end

  @impl true
  def handle_info(%{topic: "access_requests:" <> _}, socket) do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("search", %{"search" => q}, socket) do
    {:noreply,
     push_patch(socket, to: build_url(%{"search" => q, "filter" => socket.assigns.filter}))}
  end

  def handle_event("filter", %{"status" => s}, socket) do
    f = if s == "", do: nil, else: s

    {:noreply,
     push_patch(socket, to: build_url(%{"filter" => f, "search" => socket.assigns.search}))}
  end

  def handle_event("select", %{"id" => id}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         build_url(%{
           "selected" => id,
           "filter" => socket.assigns.filter,
           "search" => socket.assigns.search
         })
     )}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply,
     push_patch(socket,
       to: build_url(%{"filter" => socket.assigns.filter, "search" => socket.assigns.search})
     )}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    admin = get_admin()
    {:ok, request} = AccessGuardian.Access.get_request(id)
    AccessGuardian.Access.approve_request(request, %{approver_id: admin.id})
    {:noreply, reload(socket)}
  end

  def handle_event("deny", %{"id" => id}, socket) do
    admin = get_admin()
    {:ok, request} = AccessGuardian.Access.get_request(id)
    AccessGuardian.Access.deny_request(request, %{denier_id: admin.id, reason: "Denied by admin"})
    {:noreply, reload(socket)}
  end

  def handle_event("manual_grant", %{"id" => id}, socket) do
    admin = get_admin()
    {:ok, request} = AccessGuardian.Access.get_request(id)
    AccessGuardian.Access.complete_manual_grant(request, %{admin_id: admin.id})
    {:noreply, reload(socket)}
  end

  def handle_event("manual_reject", %{"id" => id}, socket) do
    admin = get_admin()
    {:ok, request} = AccessGuardian.Access.get_request(id)

    AccessGuardian.Access.reject_manual_grant(request, %{
      admin_id: admin.id,
      reason: "Rejected by admin"
    })

    {:noreply, reload(socket)}
  end

  defp reload(socket) do
    requests = load_requests(socket.assigns.org.id, socket.assigns.filter, socket.assigns.search)

    selected =
      if socket.assigns.selected,
        do: load_request(socket.assigns.selected.id)

    assign(socket, requests: requests, selected: selected)
  end

  defp load_requests(org_id, filter, search) do
    {:ok, results} = AccessGuardian.Access.list_by_org(org_id)

    results
    |> maybe_filter_status(filter)
    |> maybe_search(search)
  end

  defp maybe_filter_status(requests, nil), do: requests
  defp maybe_filter_status(requests, ""), do: requests

  defp maybe_filter_status(requests, status_str) do
    status = String.to_existing_atom(status_str)
    Enum.filter(requests, &(&1.status == status))
  end

  defp maybe_search(requests, nil), do: requests
  defp maybe_search(requests, ""), do: requests

  defp maybe_search(requests, search) do
    term = String.downcase(search)

    Enum.filter(requests, fn r ->
      String.contains?(String.downcase(r.affected_user.full_name), term) or
        String.contains?(String.downcase(to_string(r.affected_user.email)), term) or
        String.contains?(String.downcase(r.application.name), term)
    end)
  end

  defp load_request(id) do
    case AccessGuardian.Access.get_request(id) do
      {:ok, request} ->
        {:ok, request} =
          Ash.load(request, [:affected_user, :requested_by, :application, approvals: [:approver]])

        request

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp get_org do
    {:ok, [org | _]} = Ash.read(AccessGuardian.Catalog.Organization)
    org
  end

  defp get_admin do
    {:ok, [admin | _]} =
      AccessGuardian.Catalog.User
      |> Ash.Query.filter(org_role == :org_admin)
      |> Ash.read()

    admin
  end

  defp build_url(params) do
    params = Map.reject(params, fn {_k, v} -> is_nil(v) or v == "" end)

    case URI.encode_query(params) do
      "" -> "/requests"
      qs -> "/requests?#{qs}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-bold text-base-content">Access Requests</h1>
        <.link navigate="/" class="text-sm link link-hover text-base-content/60">← Dashboard</.link>
      </div>

      <div class="flex flex-wrap gap-3 mb-4">
        <form phx-change="search" class="flex-1 max-w-sm">
          <input
            type="text"
            name="search"
            value={@search}
            placeholder="Search by name, email, or app..."
            phx-debounce="300"
            class="input input-bordered input-sm w-full"
          />
        </form>
        <form phx-change="filter">
          <select name="status" class="select select-bordered select-sm">
            <option value="" selected={@filter == nil}>All</option>
            <option value="pending_approval" selected={@filter == "pending_approval"}>Pending</option>
            <option value="provisioning" selected={@filter == "provisioning"}>Provisioning</option>
            <option value="granted" selected={@filter == "granted"}>Granted</option>
            <option value="denied" selected={@filter == "denied"}>Denied</option>
            <option value="rejected" selected={@filter == "rejected"}>Rejected</option>
          </select>
        </form>
      </div>

      <div class="flex gap-6">
        <div class={[
          "flex-1 bg-base-100 rounded-xl border border-base-300 divide-y divide-base-200",
          @selected && "hidden lg:block"
        ]}>
          <div
            :for={req <- @requests}
            phx-click="select"
            phx-value-id={req.id}
            class={[
              "flex items-center justify-between px-4 py-3 cursor-pointer hover:bg-base-200",
              @selected && @selected.id == req.id && "bg-base-200"
            ]}
          >
            <div class="min-w-0">
              <p class="text-sm font-medium text-base-content truncate">{req.affected_user.full_name}</p>
              <p class="text-xs text-base-content/50">{req.application.name}</p>
            </div>
            <.status_badge status={req.status} pending_manual={req.pending_manual} />
          </div>
          <div :if={@requests == []} class="px-4 py-8 text-center text-sm text-base-content/50">
            No requests found.
          </div>
        </div>

        <div :if={@selected} class="w-full lg:w-[480px] shrink-0">
          <.request_detail request={@selected} />
        </div>
      </div>
    </div>
    """
  end

  defp request_detail(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl border border-base-300 p-5">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-sm font-semibold text-base-content">Request Detail</h2>
        <button phx-click="close_detail" class="text-base-content/40 hover:text-base-content/70 text-lg">
          &times;
        </button>
      </div>

      <dl class="space-y-2 text-sm">
        <div class="flex justify-between">
          <dt class="text-base-content/60">Requester</dt>
          <dd class="font-medium text-base-content">{@request.affected_user.full_name}</dd>
        </div>
        <div class="flex justify-between">
          <dt class="text-base-content/60">Application</dt>
          <dd class="text-base-content">{@request.application.name}</dd>
        </div>
        <div class="flex justify-between">
          <dt class="text-base-content/60">Status</dt>
          <dd><.status_badge status={@request.status} pending_manual={@request.pending_manual} /></dd>
        </div>
        <div :if={@request.request_reason} class="flex justify-between">
          <dt class="text-base-content/60">Reason</dt>
          <dd class="text-base-content text-right max-w-[220px]">{@request.request_reason}</dd>
        </div>
        <div :if={@request.adapter_type} class="flex justify-between">
          <dt class="text-base-content/60">Adapter</dt>
          <dd class="text-base-content">{@request.adapter_type}</dd>
        </div>
        <div :if={@request.reject_reason} class="flex justify-between">
          <dt class="text-base-content/60">Error</dt>
          <dd class="text-error text-right max-w-[220px]">{@request.reject_reason}</dd>
        </div>
        <div :if={@request.deny_reason} class="flex justify-between">
          <dt class="text-base-content/60">Denial</dt>
          <dd class="text-error text-right max-w-[220px]">{@request.deny_reason}</dd>
        </div>
      </dl>

      <div :if={@request.approvals != []} class="mt-4 pt-3 border-t border-base-200">
        <h3 class="text-xs font-semibold text-base-content/50 uppercase mb-2">Approval Timeline</h3>
        <div :for={a <- @request.approvals} class="flex items-center gap-2 text-sm py-1">
          <span class={[
            "w-2 h-2 rounded-full",
            if(a.decision == :approved, do: "bg-success", else: "bg-error")
          ]} />
          <span class="text-base-content">{a.approver.full_name}</span>
          <span :if={a.override_by_id} class="text-xs text-base-content/40">(override)</span>
          <span class="text-xs text-base-content/40">step {a.step_index}</span>
        </div>
      </div>

      <div :if={@request.status == :pending_approval} class="mt-4 pt-3 border-t border-base-200 flex gap-2">
        <button phx-click="approve" phx-value-id={@request.id} class="btn btn-success btn-sm flex-1">
          Approve
        </button>
        <button phx-click="deny" phx-value-id={@request.id} class="btn btn-error btn-sm flex-1">
          Deny
        </button>
      </div>

      <div :if={@request.pending_manual} class="mt-4 pt-3 border-t border-base-200 flex gap-2">
        <button phx-click="manual_grant" phx-value-id={@request.id} class="btn btn-success btn-sm flex-1">
          Grant Access
        </button>
        <button phx-click="manual_reject" phx-value-id={@request.id} class="btn btn-error btn-sm flex-1">
          Reject
        </button>
      </div>
    </div>
    """
  end
end
