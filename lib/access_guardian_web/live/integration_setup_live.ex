defmodule AccessGuardianWeb.IntegrationSetupLive do
  use AccessGuardianWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, apps} = Ash.read(AccessGuardian.Catalog.Application)
    notion_app = Enum.find(apps, &(&1.config["notion_workspace_url"]))

    current_session =
      if notion_app do
        case Ash.read(AccessGuardian.Catalog.IntegrationSession) do
          {:ok, sessions} ->
            Enum.find(sessions, &(&1.platform == :notion and &1.status == :active))

          _ ->
            nil
        end
      end

    {:ok,
     assign(socket,
       page_title: "Integration Setup",
       notion_app: notion_app,
       current_session: current_session,
       workspace_url: (notion_app && notion_app.config["notion_workspace_url"]) || "",
       status: nil,
       submitting: false
     )}
  end

  @impl true
  def handle_event(
        "submit_cookies",
        %{"cookies" => cookies_json, "workspace_url" => workspace_url},
        socket
      ) do
    socket = assign(socket, submitting: true, status: {:loading, "Validating cookies..."})

    case validate_and_save(cookies_json, workspace_url, socket.assigns.notion_app) do
      {:ok, session} ->
        {:noreply,
         assign(socket,
           submitting: false,
           status: {:success, "Session saved successfully. Notion integration is now active."},
           current_session: session
         )}

      {:error, message} ->
        {:noreply,
         assign(socket,
           submitting: false,
           status: {:error, message}
         )}
    end
  end

  defp validate_and_save(cookies_json, workspace_url, notion_app) do
    with {:ok, cookies} <- parse_cookies(cookies_json),
         {:ok, _} <- call_playwright_validate(cookies, workspace_url) do
      expire_existing_sessions(:notion)

      attrs = %{
        platform: :notion,
        status: :active,
        workspace_url: workspace_url,
        captured_at: DateTime.utc_now(),
        application_id: notion_app && notion_app.id
      }

      case Ash.create(AccessGuardian.Catalog.IntegrationSession, attrs) do
        {:ok, session} -> {:ok, session}
        {:error, err} -> {:error, "Failed to save session: #{inspect(err)}"}
      end
    end
  end

  defp parse_cookies(json_string) do
    case Jason.decode(json_string) do
      {:ok, cookies} when is_list(cookies) -> {:ok, cookies}
      _ -> {:error, "Invalid JSON. Make sure you copied the output from the console snippet."}
    end
  end

  defp call_playwright_validate(cookies, workspace_url) do
    service_url = System.get_env("PLAYWRIGHT_SERVICE_URL") || "http://playwright:3000"

    case Req.post("#{service_url}/validate-session",
           json: %{cookies: cookies, workspace_url: workspace_url},
           receive_timeout: 30_000,
           connect_options: [timeout: 5_000]
         ) do
      {:ok, %{status: 200, body: %{"success" => true}}} ->
        {:ok, :valid}

      {:ok, %{status: 200, body: %{"error" => error}}} ->
        {:error, error}

      {:ok, %{status: status, body: body}} ->
        {:error, "Playwright service returned #{status}: #{inspect(body)}"}

      {:error, %{reason: :econnrefused}} ->
        {:error, "Playwright service not available (connection refused)"}

      {:error, reason} ->
        {:error, "Playwright service error: #{inspect(reason)}"}
    end
  end

  defp expire_existing_sessions(platform) do
    case Ash.read(AccessGuardian.Catalog.IntegrationSession) do
      {:ok, sessions} ->
        sessions
        |> Enum.filter(&(&1.platform == platform and &1.status == :active))
        |> Enum.each(fn s ->
          Ash.update!(s, action: :mark_expired)
        end)

      _ ->
        :ok
    end
  end

  @bookmarklet_snippet "copy(JSON.stringify(document.cookie.split('; ').map(c=>{const[n,...v]=c.split('=');return{name:n,value:v.join('='),domain:'.notion.so',path:'/'}})))"

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :snippet, @bookmarklet_snippet)
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-bold text-base-content">Integration Setup</h1>
        <.link navigate="/applications" class="text-sm link link-hover text-base-content/60">
          &larr; Applications
        </.link>
      </div>

      <div :if={@current_session} class="alert alert-success mb-6">
        <div>
          <p class="font-semibold">Notion session active</p>
          <p class="text-sm opacity-80">
            Captured: {Calendar.strftime(@current_session.captured_at, "%b %d, %Y at %H:%M UTC")}
            · Workspace: {@current_session.workspace_url}
          </p>
        </div>
      </div>

      <div :if={!@current_session} class="alert alert-warning mb-6">
        <p>No active Notion session. Complete the setup below to enable Notion provisioning.</p>
      </div>

      <div class="bg-base-100 rounded-xl border border-base-300 p-5 mb-3">
        <p class="font-semibold text-sm text-base-content mb-1">
          <span class="badge badge-sm badge-neutral mr-1.5">1</span> Log into Notion
        </p>
        <p class="text-sm text-base-content/60">
          Open
          <a href="https://www.notion.so" target="_blank" class="link link-primary">notion.so</a>
          in another tab and log into the account with admin/owner access to your workspace.
        </p>
      </div>

      <div class="bg-base-100 rounded-xl border border-base-300 p-5 mb-3">
        <p class="font-semibold text-sm text-base-content mb-1">
          <span class="badge badge-sm badge-neutral mr-1.5">2</span> Copy your session cookies
        </p>
        <p class="text-sm text-base-content/60 mb-2">
          While on Notion, open your browser console (<strong>F12 &rarr; Console</strong>) and paste this snippet:
        </p>
        <div class="relative">
          <pre
            class="bg-base-200 rounded-lg p-3 text-xs font-mono overflow-x-auto"
            id="cookie-snippet"
          >{@snippet}</pre>
          <button
            class="btn btn-xs btn-neutral absolute top-2 right-2"
            onclick="navigator.clipboard.writeText(document.getElementById('cookie-snippet').textContent);this.textContent='Copied!';setTimeout(()=>this.textContent='Copy',2000)"
          >
            Copy
          </button>
        </div>
        <p class="text-xs text-base-content/40 mt-2">
          This reads cookies for the current page and copies them as JSON to your clipboard. Nothing is sent anywhere.
        </p>
      </div>

      <div class="bg-base-100 rounded-xl border border-base-300 p-5 mb-3">
        <p class="font-semibold text-sm text-base-content mb-3">
          <span class="badge badge-sm badge-neutral mr-1.5">3</span> Paste and connect
        </p>

        <form phx-submit="submit_cookies">
          <div class="mb-3">
            <label class="label text-sm font-medium">Workspace URL</label>
            <input
              type="text"
              name="workspace_url"
              value={@workspace_url}
              placeholder="https://www.notion.so/your-workspace"
              class="input input-bordered w-full text-sm"
            />
          </div>

          <div class="mb-3">
            <label class="label text-sm font-medium">Cookies JSON</label>
            <textarea
              name="cookies"
              placeholder="Paste the copied JSON here..."
              class="textarea textarea-bordered w-full font-mono text-xs"
              rows="5"
            ></textarea>
          </div>

          <button type="submit" class="btn btn-success w-full" disabled={@submitting}>
            {if @submitting, do: "Validating...", else: "Validate & Save Session"}
          </button>
        </form>

        <div :if={@status} class={["alert mt-4", status_class(@status)]}>
          {elem(@status, 1)}
        </div>
      </div>
    </div>
    """
  end

  defp status_class({:success, _}), do: "alert-success"
  defp status_class({:error, _}), do: "alert-error"
  defp status_class({:loading, _}), do: "alert-info"
end
